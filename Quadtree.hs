module Quadtree
where

--import Control.Monad
import Data.Bits

type Vec2 = (Int, Int)

data Quad a = Node  { level     :: Int
                    , _nw, _ne,
                      _sw, _se  :: Quad a
                    }
            | Empty { level     :: Int
                    }
            | Leaf  { value     :: a
                    }
            deriving (Eq, Show)

data Crumb a = NWCrumb Int           (Quad a)
                            (Quad a) (Quad a)
             | NECrumb Int  (Quad a)
                            (Quad a) (Quad a)
             | SWCrumb Int  (Quad a) (Quad a)
                                     (Quad a)
             | SECrumb Int  (Quad a) (Quad a)
                            (Quad a)
             deriving (Eq, Show)

data Zipper a = Zipper  { quad          :: Quad a
                        , breadcrumbs   :: [Crumb a]
                        } deriving (Eq, Show)

depth :: Quad a -> Int
depth Leaf{}    = 0
depth q         = level q

top :: Quad a -> Zipper a
top q = Zipper q []

adjust :: (Quad a -> Quad a) -> Zipper a -> Zipper a
adjust f (Zipper q bs) = Zipper (f q) bs

up :: Zipper a -> Maybe (Zipper a)
up (Zipper _  [])                            = Nothing
up (Zipper nw' (NWCrumb k ne' sw' se' : bs)) = Just $ Zipper (Node k nw' ne' sw' se') bs
up (Zipper ne' (NECrumb k nw' sw' se' : bs)) = Just $ Zipper (Node k nw' ne' sw' se') bs
up (Zipper sw' (SWCrumb k nw' ne' se' : bs)) = Just $ Zipper (Node k nw' ne' sw' se') bs
up (Zipper se' (SECrumb k nw' ne' sw' : bs)) = Just $ Zipper (Node k nw' ne' sw' se') bs

emptynode :: Int -> Quad a
emptynode k = Node k e e e e
    where e = Empty (k - 1)

level0 :: Zipper a -> Maybe a -> Maybe a
level0 (Zipper Leaf{}         _) _ = Nothing
level0 (Zipper Node{level=0}  _) _ = Nothing
level0 (Zipper Empty{level=0} _) _ = Nothing
level0 _                         r = r

emptyexpand :: (Zipper a -> a) -> Zipper a -> a
emptyexpand r (Zipper Empty{level=k} bs) = r (Zipper (emptynode k) bs)
emptyexpand r zipper                     = r zipper

dn :: (Quad a -> Quad a) -> (Int -> Quad a -> Quad a -> Quad a -> Crumb a) ->
      (Quad a -> Quad a) -> (Quad a -> Quad a) -> (Quad a -> Quad a) -> Zipper a ->
      Maybe (Zipper a)
dn _ _ _  _  _  (Zipper Leaf{}         _)   = Nothing
dn _ _ _  _  _  (Zipper Node{level=0}  _)   = Nothing
dn _ _ _  _  _  (Zipper Empty{level=0} _)   = Nothing
dn q b b1 b2 b3 (Zipper Empty{level=k} bs)  = dn q b b1 b2 b3 (Zipper (emptynode k) bs)
dn q b b1 b2 b3 (Zipper node           bs)  =
    Just $ Zipper (q node) (b k b1' b2' b3':bs)
    where   k   = level node
            b1' = b1 node
            b2' = b2 node
            b3' = b3 node

nw,ne,sw,se :: Zipper a -> Maybe (Zipper a)
nw = dn _nw NWCrumb _ne _sw _se
ne = dn _ne NECrumb _nw _sw _se
sw = dn _sw SWCrumb _nw _ne _se
se = dn _se SECrumb _nw _ne _sw

topmost :: Zipper a -> Zipper a
topmost zipper =
    case up zipper of
        Just z' -> topmost z'
        Nothing -> zipper

pathTo :: Vec2 -> Int -> Zipper a -> Maybe (Zipper a)
pathTo _        0 z = return z
pathTo pt@(x,y) k z =
    case p of
        (False, False) -> nw z >>= pathTo pt nk
        (True , False) -> se z >>= pathTo pt nk
        (False, True ) -> sw z >>= pathTo pt nk
        (True , True ) -> se z >>= pathTo pt nk
    where   nk = k - 1
            x' = testBit x nk
            y' = testBit y nk
            p  = (x',y')

empty :: Int -> Quad a
empty = Empty

modify :: Vec2 -> (Quad a -> Quad a) -> Quad a -> Quad a
modify pt f q =
    case path (top q) of
        Just q' -> (quad . topmost . adjust f) q'
        Nothing -> q
    where   k = depth q
            path = pathTo pt k

insert :: Vec2 -> a -> Quad a -> Quad a
insert pt val = modify pt insert'
    where   insert' _ = Leaf val

delete :: Vec2 -> Quad a -> Quad a
delete pt q = modify pt delete' q
    where   k = depth q
            delete' _ = Empty k

insertList :: Quad a -> [(Vec2, a)] -> Quad a
insertList = foldl (\acc (pt,val) -> insert pt val acc)
