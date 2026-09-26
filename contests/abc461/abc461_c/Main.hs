{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 -Wno-unused-imports -Wno-unused-matches -Wno-unused-top-binds #-}

import Control.Monad (replicateM)
import qualified Data.ByteString.Char8 as BS
import Data.Attoparsec.ByteString.Char8 hiding (take)
import qualified Data.Map.Strict as M
import Data.Char (toLower)
import qualified Data.List as L
import qualified Data.IntMap as IM

-- Common parsers -------------------------------------------------------------

int :: Parser Int
int = skipSpace *> signed decimal

integer :: Parser Integer
integer = skipSpace *> signed decimal

word :: Parser BS.ByteString
word = skipSpace *> takeWhile1 (notInClass " \t\r\n")

ints :: Int -> Parser [Int]
ints = flip replicateM int

pair :: Parser a -> Parser b -> Parser (a, b)
pair p q = (,) <$> p <*> q

pairs :: Int -> Parser [(Int, Int)]
pairs n = replicateM n $ pair int int

-- Edit here ------------------------------------------------------------------

data Input = Input Int Int [(Int, Int)]
  deriving (Show)

input :: Parser Input
input = do
  n <- int
  k <- int
  m <- int
  cvs <- pairs n
  pure $ Input k m cvs

solve :: Input -> IO ()
solve (Input k m cvs) = print (sum as + sum cs)
  where
    (imN, ysN) = L.foldl' step (IM.empty, []) cvs 
    step (im, ys) (c, v) =
      case IM.lookup c im of
        Nothing -> (IM.insert c v im, ys)       
        Just w  -> (IM.insert c (max v w) im, min v w : ys)     
    (as, bs) = splitAt m $ L.sortBy (flip compare) $ IM.elems imN 
    cs = take (k - m) $ L.sortBy (flip compare) $ bs ++ ysN 

-- Do not usually edit below ---------------------------------------------------

main :: IO ()
main = do
  bs <- BS.getContents
  case parseOnly (input <* skipSpace <* endOfInput) bs of
    Left err -> error err
    Right x  -> solve x
