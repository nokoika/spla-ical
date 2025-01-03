module ICal (ICalInput (..), ICalEvent (..), buildICalText) where

import qualified Data.Char as C
import Data.List (intercalate)
import qualified Data.Time as T
import qualified Query as Q
import qualified Translation
import Prelude (Eq, Show (show), String, concatMap, filter, (++), (.), (==))

data ICalInput = ICalInput
  { language :: Q.Language,
    events :: [ICalEvent]
  }
  deriving (Show, Eq)

data ICalEvent = ICalEvent
  { id :: String,
    summary :: String,
    description :: String,
    start :: T.UTCTime,
    end :: T.UTCTime
  }
  deriving (Show, Eq)

convertUTCTimeToLocalTime :: T.UTCTime -> T.LocalTime
convertUTCTimeToLocalTime = T.utcToLocalTime T.utc

-- 20231207T120000Z <- 2023-12-07T12:00:00Z
toICalTime :: T.UTCTime -> String
toICalTime utcTime = day ++ "T" ++ dayTime ++ "Z"
  where
    T.LocalTime {localDay, localTimeOfDay} = convertUTCTimeToLocalTime utcTime
    convert s = filter C.isDigit (show s)
    day = convert localDay
    dayTime = convert localTimeOfDay

buildICalText :: ICalInput -> String
buildICalText ICalInput {language, events} =
  intercalate
    "\n"
    [ "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:" ++ Translation.showICalProdId language,
      "METHOD:PUBLISH",
      "CALSCALE:GREGORIAN",
      "X-WR-CALNAME:" ++ Translation.showApplicationName language,
      -- ※本当はDTSTAMPもrequiredだが、セットすべき値は慎重に検討すべきであるため暫定的に省略
      aggregate
        ( \ICalEvent {id, summary, description, start, end} ->
            [ "BEGIN:VEVENT",
              "UID:" ++ id,
              "SUMMARY:" ++ summary,
              "DESCRIPTION:" ++ escapeNewLine description,
              "DTSTART:" ++ toICalTime start,
              "DTEND:" ++ toICalTime end,
              "END:VEVENT"
            ]
        )
        events,
      "END:VCALENDAR"
    ]
  where
    aggregate :: (a -> [String]) -> [a] -> String
    aggregate f = intercalate "\n" . concatMap f
    escapeNewLine :: String -> String
    escapeNewLine = concatMap (\c -> if c == '\n' then "\\n" else [c])
