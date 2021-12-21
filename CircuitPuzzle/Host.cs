using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;
using System;
using System.Collections.Generic;
using System.Text;

namespace Quantum.CircuitPuzzle
{
    class Host
    {
        static void Main(string[] args) 
        {
            var gatesPerm = new string[][] {
                new string[]{ "H", "I", "X", "Z" },
                new string[]{ "H", "I", "Z", "X" },
                new string[]{ "H", "X", "I", "Z" },
                new string[]{ "H", "X", "Z", "I" },
                new string[]{ "H", "Z", "I", "X" },
                new string[]{ "H", "Z", "X", "I" }
            };
            var sim = new QuantumSimulator();

            foreach (var gates in gatesPerm)
            {
                var thirdSatisfied = false;
                try
                {
                    TestThirdConstraint.Run(sim, new QArray<string>(gates)).Wait();
                }
                catch (Exception)
                {
                    thirdSatisfied = true;
                }
                // Console.WriteLine($"Third constraint{(thirdSatisfied ? "" : " not")} satisfied");

                var fourthSatisfied = true;
                try
                {
                    TestFourthConstraint.Run(sim, new QArray<string>(gates)).Wait();
                }
                catch (Exception)
                {
                    fourthSatisfied = false;
                }
                // Console.WriteLine($"Fourth constraint{(fourthSatisfied ? "" : " not")} satisfied");

                if (thirdSatisfied && fourthSatisfied) {
                    Console.WriteLine($"{String.Join(" ", gates)} is a solution");
                }
            }
        }
    }
}
