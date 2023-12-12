

all periods start at step 0

is_final0 = step % p0 == 0
is_final1 = step % p1 == 0







each node
	period_start  = iterations first final
	period_length = iterations between each final
	


max_period_start = max(period_starts)


example:
	s1 = 2
	p1 = 2
	s2 = 3
	p2 = 3

max_period_start = max(s1, s2) = 3
max_period_length = gcd(p1, p2) = 6

Know that that final must occur (if it does occur) after
max_period_start and before max_period_start + max_period_length

when does
ni is unknown
s1 + n1*p1 == s2 + n2*p2 
p12 = lcm(p1,p2) = p1*p2 / gcd(p1,p2)

s1 + n1*p12 == s2 + n2*p12
(s1 - s2) mod p12 = n  ? does this even make sense


p12345 = lcm(p1,p2,...,p5)


(s1,s2) + n12*(p1,p2) == s3 + n3*p3

better algorithm
p_all = lcm(p1,p2,...)
start_all = max(s1,s2,...)

move_counter = start_all

while not all are final:
    move_counter += p_all
    how to move nodes?






