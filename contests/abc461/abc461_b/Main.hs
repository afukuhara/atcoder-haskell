{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8
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

-- Edit here ------------------------------------------------------------------

data Input = Input [Int] [Int]
  deriving (Show)

input :: Parser Input
input = do
  n <- int
  a <- ints n
  b <- ints n
  pure (Input a b)

solve :: Input -> IO ()
solve (Input a b) = do
  putStrLn $ if any (\(i, ai) -> b !! (ai - 1) /= i) (zip [1 ..] a) then "No" else "Yes"

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x
