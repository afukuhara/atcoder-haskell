{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8 hiding (take)
import qualified Data.Map.Strict as M
import Data.Char (toLower)
import Data.List (sort, group, groupBy, sortBy, intercalate)
import Data.Bool
import qualified Data.Set as S

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
  n  <- int
  xs <- ints n
  pure $ Input n xs

solve :: Input -> IO ()
solve (Input n xs) = do
  let ys = filter (\x -> x /= -1) xs
  let zs = S.fromList ys

  if S.size zs < length ys then
    putStrLn "No"
  else do
    let remainingNumbers = filter (`notElem` ys) [1..n] 
    let filledMinusone = fillMinusone xs remainingNumbers 
    putStrLn "Yes"
    putStrLn $ intercalate " " $ map show filledMinusone

fillMinusone :: [Int] -> [Int] -> [Int]
fillMinusone [] _ = []
fillMinusone (-1:xs) (y:ys) = y : fillMinusone xs ys
fillMinusone (-1:_) [] = error "右のリストの要素が不足しています"
fillMinusone (x:xs) ys = x : fillMinusone xs ys

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