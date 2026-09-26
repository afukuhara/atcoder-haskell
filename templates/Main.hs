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

data Input = Input
  deriving (Show)

input :: Parser Input
input = do
  -- Example:
  --
  -- n  <- int
  -- xs <- ints n
  --
  -- Change Input above and construct it here.
  pure Input

solve :: Input -> IO ()
solve _ = do
  -- Write the answer here.
  pure ()

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x
