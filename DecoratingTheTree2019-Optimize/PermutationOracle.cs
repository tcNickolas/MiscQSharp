// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Quantum.Simulation;
using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;

namespace Microsoft.Quantum.Extensions.Oracles
{
    /// <summary>
    /// This class provides  the infrastructure to define and efficiently
    /// apply permutation oracles within a (full state) simulator.
    /// </summary>
    public class OracleEmulator
    {
        /// <summary>
        /// The main entry point for emulation of a permutation oracle:
        /// Apply the permutation defined by the oracle function
        ///     f: (x, y) -> (x, f(x, y)).
        /// </summary>
        public static void ApplyOracle(QuantumSimulator simulator, Func<Int64, Int64, Int64, Int64> oracle,
             Int64 nLayers, IQArray<Qubit> xbits, Qubit ybit, bool adjoint = false)
        {
            var permutation = BuildPermutationTable(oracle, nLayers, (int)xbits.Length, 1);
            simulator.CheckQubits(xbits, "x");
            simulator.CheckQubit(ybit, "y");
            Debug.Assert(CheckPermutation(permutation));
            IQArray<Qubit> ybits = new QArray<Qubit>(ybit);
            var qbits = QArray<Qubit>.Add(xbits, ybits).GetIds();
            if (adjoint)
                AdjPermuteBasisTable(simulator.Id, (uint)qbits.Length, qbits, permutation.LongLength, permutation);
            else
                PermuteBasisTable(simulator.Id, (uint)qbits.Length, qbits, permutation.LongLength, permutation);
        }

        /// <summary>
        /// Build a permutation table for nx- and ny-qubit registers from a permutation function.
        /// </summary>
        public static Int64[] BuildPermutationTable(Func<Int64, Int64, Int64, Int64> oracle, Int64 nLayers, int nx, int ny)
        {
            Int64 xmask = (1L << nx) - 1L;
            Int64 ymask = ((1L << ny) - 1L) << nx;
            Int64 table_size = 1L << (nx + ny);

            var permutation = new Int64[table_size];
            for (Int64 state = 0; state < table_size; ++state)
            {
                Int64 x = state & xmask;
                Int64 y = (state & ymask) >> nx;
                Int64 z = oracle(nLayers, x, y);
                Int64 result = x | (z << nx);
                permutation[state] = result;
            }

            return permutation;
        }

        /// <summary>
        /// Check whether the given permutation table is actually bijective, 
        /// i.e. a valid permutation.
        /// </summary>
        public static bool CheckPermutation(Int64[] permutation)
        {
            var mapped = new BitArray(permutation.Length);
            for (int i = 0; i < permutation.Length; ++i)
            {
                var j = (int)permutation[i];
                Debug.Assert(j >= 0 && j < permutation.Length);
                mapped[j] = true;
            }
            for (int i = 0; i < permutation.Length; ++i)
            {
                if (!mapped[i])
                    return false;
            }
            return true;
        }

        // Entry points to the simulator back-end
        [DllImport(QuantumSimulator.QSIM_DLL_NAME, ExactSpelling = true, CallingConvention = CallingConvention.Cdecl, EntryPoint = "PermuteBasis")]
        private static extern void PermuteBasisTable(uint id, uint num_qbits, [In] uint[] qbits, long table_size, [In] long[] permutation_table);
        [DllImport(QuantumSimulator.QSIM_DLL_NAME, ExactSpelling = true, CallingConvention = CallingConvention.Cdecl, EntryPoint = "AdjPermuteBasis")]
        private static extern void AdjPermuteBasisTable(uint id, uint num_qbits, [In] uint[] qbits, long table_size, [In] long[] permutation_table);
    }



    /// <summary>
    /// Factory class facilitating the creation of emulated permutation oracles from C# code.
    /// </summary>
    public class EmulatedOracleFactory
    {
        /// <summary>
        /// Register a permutation oracle as the implementation of the operation Op of the form
        ///     operation MyOracle(nLayers : Int, xbits : Qubit[], ybit : Qubit) : Unit
        ///     {
        ///         body intrinsic;
        ///         adjoint intrinsic;
        ///     }
        /// </summary>
        public static void Register<Op>(QuantumSimulator simulator, Func<Int64, Int64, Int64, Int64> permutation)
        {
            PermutationOracleImpl<Op>.RegisterPermutation(permutation);
            simulator.Register(typeof(Op), typeof(PermutationOracleImpl<Op>), typeof(ICallable));
        }


        // Infrastructure to allow for programmatic definition and registration of new oracles.
        private class PermutationOracleImpl<Op> : Adjointable<(Int64, IQArray<Qubit>, Qubit)>, ICallable
        {
            private static Dictionary<Type, Func<Int64, Int64, Int64, Int64>> registered_permutations = new Dictionary<Type, Func<Int64, Int64, Int64, Int64>>();
            public static void RegisterPermutation(Func<Int64, Int64, Int64, Int64> permutation)
            {
                registered_permutations[typeof(Op)] = permutation;
            }

            private QuantumSimulator Simulator { get; }
            private Func<Int64, Int64, Int64, Int64> Permutation { get; }

            public PermutationOracleImpl(QuantumSimulator m) : base(m)
            {
                this.Simulator = m;
                this.Permutation = registered_permutations[typeof(Op)]; ;
            }

            public PermutationOracleImpl(QuantumSimulator m, Func<Int64, Int64, Int64, Int64> permutation) : base(m)
            {
                this.Simulator = m;
                this.Permutation = permutation;
            }

            string ICallable.FullName => $"PermutationOracleImpl<{typeof(Op)}>";

            public override void Init() { }

            public override Func<(Int64, IQArray<Qubit>, Qubit), QVoid> Body => (_args) =>
            {
                var (nLayers, xbits, ybit) = _args;
                OracleEmulator.ApplyOracle(this.Simulator, this.Permutation, nLayers, xbits, ybit, adjoint: false);
                return QVoid.Instance;
            };

            public override Func<(Int64, IQArray<Qubit>, Qubit), QVoid> AdjointBody => (_args) =>
            {
                var (nLayers, xbits, ybit) = _args;
                OracleEmulator.ApplyOracle(this.Simulator, this.Permutation, nLayers, xbits, ybit, adjoint: true);
                return QVoid.Instance;
            };
        }
    }
}
