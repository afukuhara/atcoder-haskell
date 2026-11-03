{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8 hiding (take)
import qualified Data.Map.Strict as M
import Data.Char (toLower)
import Data.List (sort, scanl')
import Data.Bool
import Data.Array.IO (IOUArray, newListArray, readArray, writeArray)
import Data.Array.Unboxed (UArray, listArray, (!))

-- Common parsers -------------------------------------------------------------

int :: Parser Int
int = skipSpace *> signed decimal

integer :: Parser Integer
integer = skipSpace *> signed decimal

word :: Parser BS.ByteString
word = skipSpace *> takeWhile1 (notInClass " \t\r\n")

ints :: Int -> Parser [Int]
ints = flip replicateM int

index :: Parser Int
index = subtract 1 <$> int

indices :: Int -> Parser [Int]
indices = flip replicateM index

pair :: Parser a -> Parser b -> Parser (a, b)
pair p q = (,) <$> p <*> q

-- Edit here ------------------------------------------------------------------


data Query
  = Rotate Int
  | RangeSum Int Int
  deriving (Show)

query :: Parser Query
query = do
  t <- int
  case t of
    1 -> Rotate <$> int
    2 -> RangeSum <$> int <*> int
    _ -> fail "Unknown query type"

data Input = Input Int Int [Int] [Query]
  deriving (Show)

input :: Parser Input
input = do
  n  <- int
  q  <- int
  as <- ints n
  qs <- replicateM q query
  pure $ Input n q as qs

solve :: Input -> IO ()
solve (Input n _ as qs) = do
  let ss = scanl' (+) 0 (as ++ as)
      arr = listArray (0, 2 * n) ss :: UArray Int Int

      solver i [] = pure ()
      solver i (Rotate j : qs) =
        solver ((i + j) `mod` n) qs
      solver i (RangeSum l r : qs) = do
        let right = arr ! (r + i)
            left  = arr ! (l + i - 1)
        print $ right - left
        solver i qs

  solver 0 qs

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x


-- Library ---------------------------------------------------------------------

shakutori :: (a -> b -> Bool) -- 条件 p
         -> (b -> a -> b) -- 右端を伸ばす演算 op
         -> (b -> a -> b) -- 左端を縮める演算 invOp
         -> b -- 初期値 identity
         -> [a] -- 入力リスト as
         -> [Int] -- 条件を満たす部分列の長さのリスト
shakutori p op invOp identity as = go as as 0 identity
  where
    -- 右端が空になったら、左端を1つ縮める
    go (l:ls) [] len res = len : (go ls [] (len-1) (invOp res l))
    go lls@(l:ls) rrs@(r:rs) len res
      -- 条件 p を満たすなら、右端を1つ伸ばす
      | p r res = go lls rs (len + 1) (op res r)
      -- 長さが0であれば、スキップする
      | len == 0 = 0:(go ls rs 0 identity)
      -- 条件 p を満たさないなら、左端を1つ縮める
      | otherwise =  len : (go ls rrs (len-1) (invOp res l))
    go _ _ _ _ = []