@mod verified_contracts

@type PosInt = { x : Int | x > 0 }

@type Balance = Int
@invariant balance >= 0

@fn add @pure @req x > 0 @ens result > 0 -> Int

@fn readFile @effect IO @effect Mutation -> String

@fn transfer @effect IO @effect Mutation @req amount > 0 @ens "Balance updated" -> Bool

@fn factorial @decreases n @req n >= 0 -> Nat
