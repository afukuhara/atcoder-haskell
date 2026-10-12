{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8 hiding (take)
import qualified Data.Map.Strict as M
import Data.Char (toLower)
import Data.List (sort)

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

data Input = Input Int [Int]
  deriving (Show)

input :: Parser Input
input = do
  n <- int
  xs <- ints n
  pure (Input n xs)

solve :: Input -> IO ()
solve (Input _ xs) =
  print $ dfs 1 xs

-- 座標を2倍して扱う。
-- 現在位置と残りの移動から、最大通過回数を返す。
dfs :: Int -> [Int] -> Int
dfs _ [] = 0
dfs pos (x:xs) =
  max (score (pos + 2 * x)) (score (pos - 2 * x))
  where
    score nextPos =
      let crossed = if crossesZero pos nextPos then 1 else 0
      in crossed + dfs nextPos xs

crossesZero :: Int -> Int -> Bool
crossesZero x y =
  (x < 0 && y > 0) || (x > 0 && y < 0)

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