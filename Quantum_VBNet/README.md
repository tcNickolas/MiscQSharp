# Using Q# with Visual Basic .NET

_This post was written for the [Q# Advent Calendar 2018](https://blogs.msdn.microsoft.com/visualstudio/2018/11/15/q-advent-calendar-2018/). 
Check out the calendar for other posts!_

_Update (March 2019). This same question [was raised](https://stackoverflow.com/q/55319901/) in regard to using Q# with F#. All the steps are exactly the same, so I decided to add an F# sample using the same Q# code without spinning up a separate project. If you need to use Q# from F#, read on and replace all occurrences of VB.NET with F# :-)_

The Microsoft Quantum Development Kit documentation promises that quantum programs in Q# can be executed from classical .NET applications.
However, the examples of classical drivers both in the [documentation](https://docs.microsoft.com/en-us/quantum/quickstart) and in the [samples repository](https://github.com/Microsoft/Quantum) all use C#.
That made me wonder - what would it take to call Q# code from a driver written in Visual Basic .NET? 

You can not mix VB.NET and Q# sources in one project, because it won't compile.
Plan B is to create a Q# library (which will yield a .csproj project with only Q# files in it) and to reference it from a purely VB.NET application.
This yields two projects written in different languages but both compiling to MSIL and happy to reference one another.

The steps are as follows:

1. Create a Q# library `QuantumCode` and write your quantum code in it.

   For this example I used the last problem from [this quantum kata](https://github.com/Microsoft/QuantumKatas/tree/master/DeutschJozsaAlgorithm), 
   which solves a task similar to the Bernstein–Vazirani algorithm, but that has slightly more interesting classical answer verification code. 
   
   The problem is stated as follows: You are given a black box quantum oracle which implements a classical function 𝐹 which takes 𝑛 digits of binary input and produces a binary output.
   You are guaranteed that the function f can be represented as
   𝐹(𝑥₀, …, 𝑥ₙ₋₁) = Σᵢ (𝑟ᵢ 𝑥ᵢ + (1 - 𝑟ᵢ)(1 - 𝑥ᵢ)) mod 2 for some bit vector 𝑟 = (𝑟₀, …, 𝑟ₙ₋₁).
   Your goal is to find a bit vector which can produce the given oracle. Note that (unlike in the Bernstein–Vazirani algorithm), it doesn't have to be the same bit vector as the one used to create the oracle; if there are several bit vectors that produce the given oracle, you can return any of them.
   
   The solution is actually easier than the Bernstein–Vazirani algorithm, and is more classical than quantum. Indeed, the expression for the function 𝐹 can be simplified as follows: 𝐹(𝑥₀, …, 𝑥ₙ₋₁) = 2 Σᵢ 𝑟ᵢ 𝑥ᵢ + Σᵢ 𝑟ᵢ + Σᵢ 𝑥ᵢ + 𝑛 (mod 2) = Σᵢ 𝑟ᵢ + Σᵢ 𝑥ᵢ + 𝑛 (mod 2). You can see that the value of the function depends not on the individual values of 𝑥ᵢ, but only on the parity of their sum - that's not that much information to extract. If you apply the oracle to a qubit state |0..0⟩|0⟩, you'll get a state |0⋯0⟩|𝐹(0, ..., 0)⟩ = |0⋯0⟩|Σᵢ 𝑟ᵢ + 𝑛 (mod 2)⟩. If you measure the target qubit now, you'll get Σᵢ 𝑟ᵢ mod 2 if n is even, and Σᵢ 𝑟ᵢ + 1 mod 2 if 𝑛 is odd.
   
2. Create a VB.NET application (in this case a console app targeting .NET Core) `VBNetDriver`.
3. Add a reference to the Q# library to the VB.NET application.

   You can use [Reference Manager](https://docs.microsoft.com/en-us/visualstudio/ide/how-to-add-or-remove-references-by-using-the-reference-manager) in Visual Studio to do that, or you can add the reference from the command line:

```PowerShell
PS>  dotnet add .\VBNetDriver\VBNetDriver.vbproj reference .\QuantumCode\QuantumCode.csproj
```
   
4. Install the NuGet package `Microsoft.Quantum.Development.Kit` which adds Q# support to the VB.NET application.

   You will not be writing any Q# code in `VBNetDriver`, but you will need to use functionality provided by the QDK to create a quantum simulator to run your quantum code on, and to define data types used to pass the parameters to your quantum program.
5. Write the classical driver in `VBNetDriver`.
   The code structure is similar to the [C# example](https://docs.microsoft.com/en-us/quantum/quickstart#step-3-enter-the-c-driver-code), so I won't go into the details here.

You can find the full code (including the comments!) for both projects [here](https://github.com/tcNickolas/MiscQSharp/tree/master/Quantum_VBNet) (use `Quantum_VBNet.sln` to open the projects in Visual Studio).

I have yet to some up with a scenario in which it would be critical to write the driver in VB.NET, but at least now we know that it's possible!
