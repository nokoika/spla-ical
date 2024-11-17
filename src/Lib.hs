module Lib (generateICalEvents, someFunc) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64.URL as BU (decode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T (Text, pack)
import qualified Data.Text.Encoding as TE (decodeUtf8', encodeUtf8)
import qualified Data.Text.Lazy as TL (fromStrict)
import qualified ICal (ICalEvent (..), Reminder (..), ReminderAction (..), ReminderTimeUnit (..), ReminderTrigger (..), buildICalText)
import qualified Web.Scotty as S (ActionM, get, queryParam, scotty, text)
import Prelude (Bool (False), Either (Left, Right), Eq, IO, Int, Maybe (Just, Nothing), Show, String, ($), (.), (<>), (>>=))
import qualified Prelude as P (putStrLn, return, show, print)
import Data.Aeson (FromJSON, decode)
import GHC.Generics (Generic)


-- SplatoonStageScheduleQueryを表すデータ型
data SplatoonStageScheduleQuery = SplatoonStageScheduleQuery
  { language :: String, -- "ja" | "en"
    filters :: [FilterCondition]
  }
  deriving (Show, Eq)

-- フィルタ条件
data FilterCondition
  = MatchTypeFilter
  { matchType :: String, -- "bankara_open" | "bankara_challenge" | "x" | "regular" | "event"
    stages :: Maybe StageFilter,
    rules :: Maybe [String], -- ["TURF_WAR", "AREA", ...]
    timeSlots :: Maybe [TimeSlot],
    notifications :: Maybe [NotificationSetting]
  }
  deriving (Show, Eq)

-- ステージフィルタ
data StageFilter = StageFilter
  { matchBothStages :: Bool,
    stageIds :: [Int]
  }
  deriving (Show, Eq)

-- 時間帯
data TimeSlot = TimeSlot
  { start :: String, -- HH:mm
    end :: String, -- HH:mm
    utcOffset :: Maybe String, -- e.g., "+09:00"
    dayOfWeek :: Maybe String -- e.g., "Monday"
  }
  deriving (Show, Eq)

-- 通知設定
newtype NotificationSetting = NotificationSetting
  { minutesBefore :: Int
  }
  deriving (Show, Eq)

-- 入力クエリを受け取り、HTTPリクエストを行い、ICalEventのリストを返す
generateICalEvents ::
  SplatoonStageScheduleQuery -> -- 入力クエリ
  IO [ICal.ICalEvent] -- HTTPリクエストを行い、ICalEventのリストを返す
generateICalEvents query = do
  -- ここにHTTPリクエストを行う処理を書く
  -- 仮にダミーのデータを返す
  P.return
    [ ICal.ICalEvent
        { summary = "スプラトゥーン2 レギュラーマッチ",
          description = "スプラトゥーン2のレギュラーマッチが開催されます。",
          start = "2020-01-01T00:00:00Z",
          end = "2020-01-01T01:00:00Z",
          url = Just "https://example.com",
          reminders =
            [ ICal.Reminder
                { trigger = ICal.ReminderTrigger {time = 15, unit = ICal.Minute},
                  action = ICal.Display
                },
              ICal.Reminder
                { trigger = ICal.ReminderTrigger {time = 1, unit = ICal.Hour},
                  action = ICal.Email
                }
            ]
        },
      ICal.ICalEvent
        { summary = "スプラトゥーン2 ガチエリア",
          description = "スプラトゥーン2のガチエリアが開催されます。",
          start = "2020-01-01T01:00:00Z",
          end = "2020-01-01T02:00:00Z",
          url = Just "https://example.com",
          reminders =
            [ ICal.Reminder
                { trigger = ICal.ReminderTrigger {time = 10, unit = ICal.Minute},
                  action = ICal.Display
                },
              ICal.Reminder
                { trigger = ICal.ReminderTrigger {time = 30, unit = ICal.Minute},
                  action = ICal.Display
                }
            ]
        }
    ]

someFunc :: IO ()

hoge = do
  let query =
        SplatoonStageScheduleQuery
          { language = "ja",
            filters =
              [ MatchTypeFilter
                  { matchType = "regular",
                    stages = Just $ StageFilter {matchBothStages = False, stageIds = [1, 2]},
                    rules = Just ["TURF_WAR"],
                    timeSlots = Just [TimeSlot {start = "00:00", end = "01:00", utcOffset = Just "+09:00", dayOfWeek = Just "Monday"}],
                    notifications = Just [NotificationSetting {minutesBefore = 15}]
                  }
              ]
          }
  events <- generateICalEvents query
  P.putStrLn $ ICal.buildICalText events (language query)

fuga =
  S.scotty 3000 $
    S.get "/decode" $
      (S.queryParam "data" :: S.ActionM T.Text) >>= \base64Uri -> S.text $ case decodeBase64UriToJson $ TE.encodeUtf8 base64Uri of
        Left err -> TL.fromStrict $ T.pack err
        Right decodedText -> TL.fromStrict decodedText

decodeBase64UriToJson :: BS.ByteString -> Either String T.Text
decodeBase64UriToJson base64Uri = case BU.decode base64Uri of
  Left err -> Left $ P.show err
  Right decoded -> case TE.decodeUtf8' decoded of
    Left err -> Left $ P.show err
    Right decodedText -> Right decodedText

data Person = Person
  { name :: String,
    age :: Int
  }
  deriving (Show, Generic)
instance FromJSON Person

someFunc = do
  let jsonString :: T.Text
      jsonString = "{\"name\":\"Charlie\",\"age\":28}"

  -- Text を ByteString に変換してから decode する
  let person = decode (BL.fromStrict $ TE.encodeUtf8 jsonString) :: Maybe Person
  case person of
    Just p  -> P.print p
    Nothing -> P.putStrLn "Failed to parse JSON"
