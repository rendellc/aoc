


Want to iterate N = 1'000'000'000 cycles

Expect that iterations will reach loop after a certian number of iterations.


Say it take K iterations to reach a loop.
Meaning at iteration K, we detect an identical prior state V.

0 <= V < K < N

example:
0 <= 3 < 10 < N

Period length: P = K - V = 7

N iterations for large N is equivalent to 
Neq = V + ((N - V) % P)

example:
Neq = 3 + (1'000'000'000 - 3) % 7 = 3+3 = 6


full example:
K = 93
V = 69
P = 24
Neq = 69 + (1'000'000'000 - 69) % 24 = 69 + 19 = 88








