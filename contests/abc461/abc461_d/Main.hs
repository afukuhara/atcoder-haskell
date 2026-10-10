{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8
import qualified Data.Map.Strict as M
import Data.Char (toLower, digitToInt)
import Data.List (foldl', scanl', transpose)

-- Common parsers -------------------------------------------------------------

int :: Parser Int
int = skipSpace *> signed decimal

integer :: Parser Integer
integer = skipSpace *> signed decimal

word :: Parser BS.ByteString
word = skipSpace *> takeWhile1 (notInClass " \t\r\n")

ints :: Int -> Parser [Int]
ints = flip replicateM int

-- Edit here ------------------------------------------------------------------

data Input = Input Int Int Int [[Int]]
  deriving (Show)

input :: Parser Input
input = do
  h <- int
  w <- int
  k <- int
  grid <- replicateM h $ map digitToInt . BS.unpack <$> word
  pure $ Input h w k grid

solve :: Input -> IO ()
solve (Input h w k grid) = do
  let
    -- 上下端として選ぶ辺を短い方にする。
    -- これにより計算量は O(min(H,W)^2 * max(H,W)) になる。
    (height, width, rows)
      | h <= w    = (h, w, grid)
      | otherwise = (w, h, transpose grid)

    -- 上端 top を固定したときの答え。
    countFromTop :: Int -> Integer
    countFromTop top =
      let
        targetRows = drop top rows

        -- bottomを1行ずつ下げたときの列ごとの合計。
        --
        -- 例：
        -- [0,1,0]
        -- [1,1,0]
        --
        -- なら、
        -- bottom = top     のとき [0,1,0]
        -- bottom = top + 1 のとき [1,2,0]
        columnSums =
          tail $
            scanl'
              (zipWith (+))
              (replicate width 0)
              targetRows
      in
        foldl'
          (\acc xs -> acc + countExactly k xs)
          0
          columnSums

    !answer =
      foldl'
        (\acc top -> acc + countFromTop top)
        0
        [0 .. height - 1]

  print answer

-- 非負整数列xsについて、合計がちょうどtargetになる連続部分列の個数。
countExactly :: Int -> [Int] -> Integer
countExactly target xs =
  countAtMost target xs - countAtMost (target - 1) xs

-- 非負整数列xsについて、合計がlimit以下になる連続部分列の個数。
countAtMost :: Int -> [Int] -> Integer
countAtMost limit xs =
  foldl'
    (\acc len -> acc + fromIntegral len)
    0
    ( shakutori
        (\rightElement currentSum ->
           currentSum + rightElement <= limit
        )
        (+)
        (-)
        0
        xs
    )

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x

-- Library ---------------------------------------------------------------------

shakutori :: (a -> b -> Bool) -- 条件 p
           -> (b -> a -> b)   -- 右端を伸ばす演算 op
           -> (b -> a -> b)   -- 左端を縮める演算 invOp
           -> b               -- 初期値 identity
           -> [a]             -- 入力リスト as
           -> [Int]           -- 条件を満たす部分列の長さのリスト
shakutori p op invOp identity as = go as as 0 identity
  where
    -- 右端が空になったら、左端を1つ縮める
    go (l:ls) [] !len !res =
      len : go ls [] (len - 1) (invOp res l)

    go lls@(l:ls) rrs@(r:rs) !len !res
      -- 条件 p を満たすなら、右端を1つ伸ばす
      | p r res =
          go lls rs (len + 1) (op res r)

      -- 長さが0であれば、左右を1つずつスキップする
      | len == 0 =
          0 : go ls rs 0 identity

      -- 条件 p を満たさないなら、左端を1つ縮める
      | otherwise =
          len : go ls rrs (len - 1) (invOp res l)

    go _ _ _ _ = []