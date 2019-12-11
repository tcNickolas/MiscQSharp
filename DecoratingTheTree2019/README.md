# Decorating the Christmas Tree Using Grover's Search
## Part 2: Growing with the Tree

_This post was written for the [Q# Advent Calendar 2019](https://devblogs.microsoft.com/qsharp/q-advent-calendar-2019/). 
Check out the calendar for other cool posts!_

_This post (quite obviously) continues the blog post [Decorating the Christmas Tree Using Grover's Search](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree). You might want to read it first to get familiar with the oracles discussed in this post._

Remember that special Christmas tree at the North Pole that is Mrs.Claus' favorite and has to be decorated in a very particular way? 
Last year we developed a proper quantum solution to the problem of placing the ornaments on the tree, but Santa's elves beat us to the actual decorating. 
Let's get started early this year! We still have the code from the last year, so we can just run it and...

Hold on a second. In the last year the tree has grown! 
Now it has four layers of branches instead of just three:

	   X
	  XXX
	 XXXXX
	XXXXXXX
	   |

Fortunately, the rules for decorating it are still the same:

* First, there has to be exactly one ornament on each layer of the tree (Mrs.Claus brought out an extra ornament for the fourth layer). 
* Second, no two ornaments should be vertically adjacent to each other.

Let's see if we can take our old code and update it so that it would be able to handle a tree of an arbitrary height 
(this little tree certainly looks like it's not done growing yet!)

## Step 0: Upgrade to the latest QDK 

The old code was written in Q# 0.3, and the latest version as of December 3rd is 0.10. 
Let's update the code to the new version, so that we can take advantage of new language features.

The new `within ... apply` construct will come especially handy; a lot of quantum oracles, including ours, follow the pattern of "compute intermediary results - compute final result - uncompute intermediary results", which is neatly encapsulated by this construct.
This means, among other changes, that we can merge operations `MarkValidPairs` and `MarkValidLayers` into the oracles that call them.


## Step 1: Use jagged arrays for tree layers

The first thing that begs to be rewritten is the way the layers of branches (represented by qubits) are stored: 
the branches of all layers are jammed together in a one-dimensional array, so the constraints are more obscure than they have to be.

Grover's search algorithm treats all the qubits the same, so it makes sense to keep its implementation unchanged, and modify only the oracles in `TreeDecorationOracle.qs`. 
Let's start with the entry point to this file - operation `Oracle_IsValidTreeDecoration` which is used by Grover's search.

We'll use a [jagged array](https://docs.microsoft.com/quantum/language/expressions#jagged-arrays) to represent the layers of the branches: layer 0 will have 1 branch, layer 1 - 3 branches, and so on, layer J will have 2*J + 1 branches. For example, the variable assignment we used last year

          x0
	   x1 x2 x3
    x4 x5 x6 x7 x8

Will become 

                    x[0][0]
	        x[1][0] x[1][1] x[1][2]
    x[2][0] x[2][1] x[2][2] x[2][3] x[2][4]


To simplify the wrangling of qubits into the new array, we'll use a couple of Q# tricks: 

* We need `nLayers` of qubits, with 1, 3, ..., 2*`nLayers` - 1 elements in each layer; we can construct a corresponding sequence as a range `1 .. 2 .. 2 * nLayers - 1`.
* Convert this range into an array of integers using the [RangeAsIntArray](https://docs.microsoft.com/qsharp/api/qsharp/microsoft.quantum.convert.rangeasintarray) library function.
* Partition the one-dimensional array of qubits taken by `Oracle_IsValidTreeDecoration` into arrays of corresponding length 
  using the [Partitioned](https://docs.microsoft.com/qsharp/api/qsharp/microsoft.quantum.arrays.partitioned) library function.

The actual code is a single line:

    // Arrange the branches of the tree (the qubits) as a jagged array
    // by partitioning the elements of the input register into batches of 1, 3, ... , 2 * nLayers - 1 qubits
    let branches = Partitioned(RangeAsIntArray(1 .. 2 .. 2 * nLayers - 1), register);

We'll switch the rest of the oracles to use this kind of array instead of the flat array as well in just a moment.

## Step 2. Rewrite "one ornament per layer" constraint

`Oracle_OneOrnamentPerLayer` becomes a lot simpler with the new representation:
we can use the whole layer as control qubits, and all the magic in index calculation is gone.

    operation Oracle_OneOrnamentPerLayer (nLayers : Int, branches: Qubit[][], target: Qubit) : Unit is Adj {
        using (extra = Qubit[nLayers]) {
            within {
                for (layerInd in 0 .. nLayers - 1) {
                    let bits = new Bool[2 * layerInd + 1];
                    for (branchInd in 0 .. 2 * layerInd) {
                        (ControlledOnBitString(bits w/ branchInd <- true, X))(branches[layerInd], extra[layerInd]);
                    }
                }
            } apply {
                Controlled X(extra, target);
            }
        }
    }

## Step 3. Rewrite "no ornaments vertically adjacent to each other" constraint

`Oracle_NoVerticallyAdjacentOrnaments` requires a bit more work to update to handle an arbitrary number of layers: 
the pairs of indices of adjacent qubits used to be hardcoded for a 3-layer tree, and we'll need to calculate them dynamically now.

To figure out the general rule for the indices of vertically adjacent branches, let's take a look at the picture for a 3-layer tree once more:

                    x[0][0]
	        x[1][0] x[1][1] x[1][2]
    x[2][0] x[2][1] x[2][2] x[2][3] x[2][4]

First, we notice that there is one pair of vertically adjacent branches for each branch in the layers above the bottom layer; so a tree with `nLayers` layers of branches will have `(nLayers - 1)²` pairs.

Second, a branch K in layer J will have a branch K+1 in layer J+1 directly under it, which gives us the rule for figuring out the indices for adjacent pairs.

    operation Oracle_NoVerticallyAdjacentOrnaments (nLayers : Int, branches: Qubit[][], target: Qubit) : Unit is Adj {
        using (extra = Qubit[(nLayers - 1) ^ 2]) {
            let extraLayered = Partitioned(RangeAsIntArray(1 .. 2 .. 2 * (nLayers - 1) - 1), extra);
            within {
                for (layerInd in 0 .. nLayers - 2) {
                    for (branchInd in 0 .. 2 * layerInd) {
                        Controlled X([branches[layerInd][branchInd], branches[layerInd + 1][branchInd + 1]],
                                     extraLayered[layerInd][branchInd]);
                        X(extraLayered[layerInd][branchInd]);
                    }
                }
            } apply {
                Controlled X(extra, target);
            }
        }
    }


## Step 4. Calculating the number of iterations for Grover's algorithm

The last piece to update is the number of Grover iterations to run for each size of the tree.

If the tree has `nLayers` layers, it will have `nLayers²` branches and as many independent variables, so the size of the search space is 2<sup>nLayers²</sup>.

The number of valid solutions can be estimated as follows: the position of the ornament in the first layer is defined uniquely, 
and for each next layer the ornament can be in any position except one, so the total number of solutions is 1 * (3 - 1) * (5 - 1) * ... * (2 * nLayers - 1 - 1).

The number of iterations is calculated as  π/4 * sqrt(space_size/solutions_number).
Here is a small table for different tree sizes:

| Layers | Search space size | Number of solutions | Number of iterations |
|:---:| ---:| ---:| ---:|
|  1  |    2|  1  |  1  |
|  2  |   16|  2  |  2  |
|  3  |  512|  8  |  6  |
|  4  |65536|  48 | 29  |


## I have the elves on standby...

Are we done yet? Let's run [the code](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree2019) and see! 
You can configure the number of layers in the tree in `Driver.cs` file.

We can reproduce last year's results for three layers easily:

      0
     0XX
    XXXX0
      |

Two layers are even easier to solve, if we ever want to time-travel back to December 2017 and decorate the sapling of a tree right after Q# was released:

	 0
	XX0
	 |

Time-traveling back to 2016 to catch the tree when it had but a single branch would probably not be worth it, but you can check for yourself that the code solves this case correctly as well.

But when we try to find a solution for 4 layers, the code takes a long time to run - way longer than I'm prepared to wait. What's going on?

Turns out it is not enough to write the quantum program to run on inputs of  arbitrary sizes; 
one also has to be conscious of the resources it will need to run, and prepared to optimize the code to fit into the resources available.

In the [next part of this blog](../DecoratingTheTree2019-Optimize#decorating-the-christmas-tree-using-grovers-search) post we'll take a look at estimating the  resources necessary to execute the quantum program and at some tricks that can be used to optimize it. 

*After all, the elves will never let me live it down if the quantum solution will not be ready in time for the second year in a row...*

