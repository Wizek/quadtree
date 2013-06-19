module Quadtree
where

import Data.Bits

type Vec2 = (Int, Int)

data Quad a = Node { _nw, _ne,
                     _sw, _se   :: Quad a }
            | Empty
            | Leaf a
            deriving (Eq, Show)

data Crumb a = NWCrumb           (Quad a)
                        (Quad a) (Quad a)
             | NECrumb  (Quad a)
                        (Quad a) (Quad a)
             | SWCrumb  (Quad a) (Quad a)
                                 (Quad a)
             | SECrumb  (Quad a) (Quad a)
                        (Quad a)
             deriving (Eq, Show)

data Zipper a = Zipper  { quad          :: Quad a
                        , pos           :: Vec2
                        , height        :: Int
                        , breadcrumbs   :: [Crumb a]
                        } deriving (Eq, Show)

up :: Zipper a -> Maybe (Zipper a)
up (Zipper _ _     _ []    ) = Nothing
up (Zipper q (x,y) h (b:bs)) = Just $ Zipper q' p' h' bs
    where   collapse Empty Empty Empty Empty = Empty
            collapse nw'   ne'   sw'   se'   = Node nw' ne' sw' se'
            h' = h + 1
            p' = (clearBit x h, clearBit y h)
            q' = case b of
                    NWCrumb ne' sw' se' -> collapse q   ne' sw' se'
                    NECrumb nw' sw' se' -> collapse nw' q   sw' se'
                    SWCrumb nw' ne' se' -> collapse nw' ne' q   se'
                    SECrumb nw' ne' sw' -> collapse nw' ne' sw' q

dn :: (Quad a -> Quad a) -> (Quad a -> Crumb a) -> Vec2 -> Zipper a -> Maybe (Zipper a)
dn _    _        _      (Zipper _ _     0 _ ) = Nothing
dn qsel mkcrumb (xb,yb) (Zipper q (x,y) h bc) =
    case q of Node{}    -> Just $ Zipper q' p' h' b'
              _         -> Nothing
    where   expand Empty    = Node Empty Empty Empty Empty
            expand nonempty = nonempty
            setbit a ab     = a .|. (ab * bit h')
            eq  = expand q
            q'  = qsel eq
            p'  = (setbit x xb, setbit y yb)
            h'  = h - 1
            b'  = mkcrumb eq:bc

nw, ne, sw, se :: Zipper a -> Maybe (Zipper a)
nw = dn _nw nwCrumb (0,0)
ne = dn _ne neCrumb (1,0)
sw = dn _sw swCrumb (0,1)
se = dn _se seCrumb (1,1)

makeCrumb :: (Quad a -> Quad a -> Quad a -> Crumb a) -> (Quad a -> Quad a) -> (Quad a -> Quad a) -> (Quad a -> Quad a) -> Quad a -> Crumb a
makeCrumb c b1 b2 b3 q = c (b1 q) (b2 q) (b3 q)

nwCrumb, neCrumb, swCrumb, seCrumb :: Quad a -> Crumb a
nwCrumb = makeCrumb NWCrumb _ne _sw _se
neCrumb = makeCrumb NECrumb _nw _sw _se
swCrumb = makeCrumb SWCrumb _nw _ne _se
seCrumb = makeCrumb SECrumb _nw _ne _sw

top :: Zipper a -> Maybe (Zipper a)
top zipper =
    case up zipper of
        Just z  -> top z
        Nothing -> return zipper

to :: Vec2 -> Zipper a -> Maybe (Zipper a)
to (tx,ty) z =
    up' z >>= dn'
    where
        up' z'@(Zipper _ (x,y) h _) =
            let sr i = shiftR i h
            in  if (sr x, sr y) == (sr tx, sr ty)
                then Just z'
                else up z' >>= up'
        dn' z'@(Zipper _ _ h _) =
            if h == 0
            then Just z'
            else
                let tb i = testBit i (h - 1)
                in case (tb tx, tb ty) of
                        (False, False)  -> nw z' >>= dn'
                        (True,  False)  -> ne z' >>= dn'
                        (False, True )  -> sw z' >>= dn'
                        (True , True )  -> se z' >>= dn'

view :: Zipper a -> Maybe (Quad a)
view (Zipper q _ h _) =
    case h of
        0   -> Just q
        _   -> Nothing

set :: Quad a -> Zipper a -> Maybe (Zipper a)
set v (Zipper _ p h bc) =
    case h of
        0   -> Just (Zipper v p h bc)
        _   -> Nothing

modify :: (Quad a -> Quad a) -> Zipper a -> Maybe (Zipper a)
modify f (Zipper q p h bc) =
    case h of
        0   -> Just (Zipper (f q) p h bc)
        _   -> Nothing
