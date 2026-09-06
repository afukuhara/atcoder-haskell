{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8
import qualified Data.Map.Strict as M
import Data.Char (toLower)

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

data Input = Input Int Int Int Int Int Int
  deriving (Show)

input :: Parser Input
input = do
  a <- int
  b <- int
  c <- int
  d <- int
  e <- int
  f <- int
  pure (Input a b c d e f)

solve :: Input -> IO ()
solve (Input x y l r a b) = do
  print $
    sum [if e >= l && e < r then x else y | e <- [a .. b - 1]]

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x
