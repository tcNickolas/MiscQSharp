// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#nullable enable

using System;
using System.Linq;

namespace Microsoft.Quantum.Samples.SudokuGrover
{
    class Program
    {
        /// <summary>
        /// Main entry point.
        /// </summary>
        static void Main(string[] args)
        {
            // Reference answer for 4x4 sudoku we'll be using as an example.
            int[,] answer4 = {
                { 1,2,3,4 },
                { 3,4,1,2 },
                { 2,3,4,1 },
                { 4,1,2,3 } };

            // Solve 4x4 puzzle with 7 missing numbers (fast).
            int[,] puzzle4_3 = {
                { 0,2,0,4 },
                { 3,0,0,2 },
                { 0,3,0,1 },
                { 4,0,2,3 } };
            Console.WriteLine("Solving 4x4 Sudoku:");
            ShowGrid(puzzle4_3);
            SudokuQuantum sudokuQuantum = new SudokuQuantum();
            bool resultFound = sudokuQuantum.QuantumSolve(puzzle4_3).Result;
            VerifyAndShowResult(resultFound, puzzle4_3, answer4);
        }

        /// <summary>
        /// If result was found, verify it is correct (matches the answer) and show it
        /// </summary>
        /// <param name="resultFound">True if a result was found for the puzzle</param>
        /// <param name="puzzle">The puzzle to verify</param>
        /// <param name="answer">The correct puzzle result</param>
        static void VerifyAndShowResult(bool resultFound, int[,] puzzle, int[,] answer)
        {
            if (!resultFound)
                Console.WriteLine("No solution found.");
            else
            {
                bool good = puzzle.Cast<int>().SequenceEqual(answer.Cast<int>());
                if (good)
                    Console.WriteLine("Result verified correct.");
                ShowGrid(puzzle);
            }
        }

        /// <summary>
        /// Display the puzzle
        /// </summary>
        static void ShowGrid(int[,] puzzle)
        {
            int size = puzzle.GetLength(0);
            Console.WriteLine("┌───┬───┬───┬───┐");
            for (int i = 0; i < size; i++)
            {
                if (i > 0)
                    Console.WriteLine("├───┼───┼───┼───┤");
                for (int j = 0; j < size; j++)
                {
                    if (puzzle[i, j] == 0)
                        Console.Write("│   ");
                    else
                        Console.Write($"│ {puzzle[i, j],1} ");
                }
                Console.WriteLine("│");
            }
            Console.WriteLine("└───┴───┴───┴───┘");
        }
    }
}
