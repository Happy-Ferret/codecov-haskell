{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}

-- |
-- Module:      Trace.Hpc.Codecov.Curl
-- Copyright:   (c) 2014 Guillaume Nargeot
-- License:     BSD3
-- Maintainer:  Guillaume Nargeot <guillaume+hackage@nargeot.com>
-- Stability:   experimental
--
-- Functions for sending coverage report files over http.

module Trace.Hpc.Codecov.Curl ( postJson, readCoverageResult, PostResult (..) ) where

import           Control.Monad
import           Data.Aeson
import           Data.Aeson.Types (parseMaybe)
import qualified Data.ByteString.Lazy.Char8 as LBS
import           Data.Maybe
import           Network.Curl
import           Trace.Hpc.Codecov.Types

parseResponse :: CurlResponse -> PostResult
parseResponse r = case respCurlCode r of
    CurlOK -> PostSuccess (getField "url") (getField "wait_url")
    _      -> PostFailure $ getField "message"
    where getField fieldName = fromJust $ mGetField fieldName
          mGetField fieldName = do
              result <- decode $ LBS.pack (respBody r)
              parseMaybe (.: fieldName) result

-- | Send json coverage report over HTTP using POST request
postJson :: String        -- ^ json coverage report
         -> URLString     -- ^ target url
         -> Bool          -- ^ print response body if true
         -> IO PostResult -- ^ POST request result
postJson jsonCoverage url printResponse = do
    h <- initialize
    setopt h (CurlPost True)
    setopt h (CurlVerbose True)
    setopt h (CurlURL url)
    setopt h (CurlHttpHeaders ["Content-Type: application/json"])
    setopt h (CurlPostFields [jsonCoverage])
    r <- perform_with_response_ h
    when printResponse $ putStrLn $ respBody r
    return $ parseResponse r

extractCoverage :: String -> Maybe String
extractCoverage rBody = case getField "coverage" :: Maybe Integer of
    Just coverage -> Just $ show coverage ++ "%"
    Nothing -> Just $ "Failure. Response body: " ++ rBody
    where getField fieldName = do
              result <- decode $ LBS.pack rBody
              parseMaybe (.: fieldName) result

-- | Read the coveraege result page from coveralls.io
readCoverageResult :: URLString         -- ^ target url
                   -> Bool              -- ^ print json response if true
                   -> IO (Maybe String) -- ^ coverage result
readCoverageResult url printResponse = do
    response <- curlGetString url curlOptions
    when printResponse $ putStrLn $ snd response
    return $ case response of
        (CurlOK, body) -> extractCoverage body
        _ -> Just "Erroneous Curl return code"
    where curlOptions = [
              CurlTimeout 60,
              CurlConnectTimeout 60,
              CurlVerbose True]
