{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Galley.Options where

import Control.Lens hiding ((.=))
import Data.Aeson.TH (deriveFromJSON)
import Data.ByteString.Conversion
import Data.Default
import Data.Text (Text)
import Data.Monoid
import Galley.Aws (AWSEndpoint(..))
import GHC.Generics
import Data.String
import Options.Applicative
import Options.Applicative.Types
import Util.Options
import Util.Options.Common

data Settings = Settings
    { _setHttpPoolSize :: !Int
    , _setMaxTeamSize  :: !Int  -- NOTE: This must be in sync with brig
    , _setIntraListing :: !Bool -- call Brig for device listing
    } deriving (Show, Generic)

deriveFromJSON toOptionFieldName ''Settings
makeLenses ''Settings

-- [Note: journaling]
-- Journaling can be disabled simply by not passing the JournalOpts when starting the service

data JournalOpts = JournalOpts
    { _awsQueueName :: !Text
    , _awsEndpoint  :: !AWSEndpoint
    } deriving (Show, Generic)

deriveFromJSON toOptionFieldName ''JournalOpts
makeLenses ''JournalOpts

data Opts = Opts
    { _optGalley    :: !Endpoint
    , _optCassandra :: !CassandraOpts
    , _optBrig      :: !Endpoint
    , _optGundeck   :: !Endpoint
    , _optDiscoUrl  :: !(Maybe Text)
    , _optSettings  :: !Settings
    , _optJournal   :: !(Maybe JournalOpts)
    }

deriveFromJSON toOptionFieldName ''Opts
makeLenses ''Opts

parseOptions :: IO Opts
parseOptions = execParser (info (helper <*> optsParser) desc)
  where
    desc = header "Galley - Conversation Service" <> fullDesc

optsParser :: Parser Opts
optsParser = Opts <$>
    (Endpoint <$>
        (textOption $
            long "host"
            <> value "*4"
            <> showDefault
            <> metavar "HOSTNAME"
            <> help "Hostname or address to bind to")
        <*>
        (option auto $
            long "port"
            <> short 'p'
            <> metavar "PORT"
            <> help "Port to listen on"))
  <*> cassandraParser
  <*> brigParser
  <*> gundeckParser
  <*> optional discoUrlParser
  <*> settingsParser
  <*> optional journalOptsParser
  where
    brigParser :: Parser Endpoint
    brigParser = Endpoint
        <$> (textOption $
                long "brig-host"
                <> metavar "HOSTNAME"
                <> help "Brig hostname")
        <*>  (option auto $
                long "brig-port"
                <> metavar "PORT"
                <> help "Brig port")

    gundeckParser :: Parser Endpoint
    gundeckParser = Endpoint
        <$> (textOption $
                long "gundeck-host"
                <> metavar "HOSTNAME"
                <> help "Gundeck hostname")
        <*> (option auto $
                long "gundeck-port"
                <> metavar "PORT"
                <> help "Gundeck port")

    settingsParser :: Parser Settings
    settingsParser = Settings
        <$> (option auto $
                long "http-pool-size"
                <> metavar "SIZE"
                <> showDefault
                <> help "number of connections for the http client pool"
                <> value 128)
        <*>
            (option auto $
                long "team-max-size"
                <> metavar "INT"
                <> showDefault
                <> help "Max. # of members in a team."
                <> value 128)
        <*>
            (switch $
                long "intra-device-listing"
                <> help "Use this option if you want to fetch the device list from brig instead.")

journalOptsParser :: Parser JournalOpts
journalOptsParser = JournalOpts
    <$> (textOption $
            long "team-events-queue-name"
            <> metavar "STRING"
            <> help "sqs queue name to send team events")
    <*> (option parseEndpoint $
            long "aws-endpoint"
            <> value def
            <> metavar "STRING"
            <> showDefault
            <> help "aws endpoint")
  where
    parseEndpoint :: ReadM AWSEndpoint
    parseEndpoint = readerAsk >>= maybe (error "Could not parse AWS endpoint") return . fromByteString . fromString
