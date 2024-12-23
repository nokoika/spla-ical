module Filter.Internal.ICal
  ( createIcalInput,
    createICalEventsFromDefaultSchedules,
    createICalEventsFromEventMatches,
  )
where

import qualified Data.Maybe as M
import Data.Time as T
import qualified Date
import qualified Filter.Internal.Schedule as FS
import qualified Hash
import qualified ICal as I
import qualified Query as Q
import qualified SplaApi as S
import qualified Translation
import Prelude (Maybe (Just), String, show, ($), (++), (==))

convertNotificationsToReminders :: [Q.NotificationSetting] -> [I.Reminder]
convertNotificationsToReminders notifications =
  [ I.Reminder {I.trigger = I.ReminderTrigger {I.time = minutesBefore}, I.action = I.Display}
    | Q.NotificationSetting {Q.minutesBefore} <- notifications
  ]

eventId :: Q.Language -> Q.Mode -> S.Rule -> [S.Stage] -> T.UTCTime -> T.UTCTime -> String
eventId language mode apiRule apiStages start end =
  Hash.sha256Hash $ show start ++ show end ++ show apiRule ++ show apiStages ++ show language ++ show mode

createICalEventsFromDefaultSchedules :: Q.QueryRoot -> [S.DefaultSchedule] -> Q.Mode -> [I.ICalEvent]
createICalEventsFromDefaultSchedules Q.QueryRoot {utcOffset, filters, language} defaultSchedules mode =
  [ I.ICalEvent
      { I.id = eventId language mode apiRule apiStages startTime endTime,
        I.summary = Translation.showCalendarSummary language mode apiRule apiStages,
        I.description = Translation.showCalendarDescription language mode apiRule apiStages timeRange,
        I.start = startTime,
        I.end = endTime,
        I.reminders = convertNotificationsToReminders (M.fromMaybe [] (Q.notifications filter))
      }
    | defaultSchedule@S.DefaultSchedule {startTime, endTime, rule = Just apiRule, stages = Just apiStages} <- defaultSchedules,
      let Q.UtcOffsetTimeZone utcOffset' = utcOffset
          timeRange = (Date.changeTimeZone startTime utcOffset', Date.changeTimeZone endTime utcOffset'),
      filter <- filters,
      FS.filterDefaultSchedule filter defaultSchedule utcOffset' mode
  ]

createICalEventsFromEventMatches :: Q.QueryRoot -> [S.EventMatch] -> [I.ICalEvent]
createICalEventsFromEventMatches Q.QueryRoot {utcOffset, filters, language} eventMatches =
  [ I.ICalEvent
      { -- API では日本語のイベント名しか手に入らないので、日本語以外の場合は末尾にイベント名を追加する。descも同様
        I.id = eventId language Q.Event apiRule apiStages startTime endTime,
        I.summary =
          if language == Q.Japanese
            then eventName ++ baseSummary
            else baseSummary ++ " / " ++ eventName,
        I.description =
          if language == Q.Japanese
            then eventDescription ++ "\n\n" ++ baseDescription
            else baseDescription ++ "\n\n" ++ eventDescription,
        I.start = startTime,
        I.end = endTime,
        I.reminders = convertNotificationsToReminders (M.fromMaybe [] (Q.notifications filter))
      }
    | eventMatch@S.EventMatch
        { S.startTime,
          S.endTime,
          S.rule = apiRule,
          S.stages = apiStages,
          eventSummary = S.EventSummary {name = eventName, desc = eventDescription}
        } <-
        eventMatches,
      let Q.UtcOffsetTimeZone utcOffset' = utcOffset
          timeRange = (Date.changeTimeZone startTime utcOffset', Date.changeTimeZone endTime utcOffset')
          baseSummary = Translation.showCalendarSummary language Q.Event apiRule apiStages
          baseDescription = Translation.showCalendarDescription language Q.Event apiRule apiStages timeRange,
      filter <- filters,
      FS.filterEventMatch filter eventMatch utcOffset'
  ]

createIcalInput :: Q.QueryRoot -> S.Result -> I.ICalInput
createIcalInput queryRoot result =
  I.ICalInput
    { I.language = Q.language queryRoot,
      I.events = regular ++ bankaraChallenge ++ bankaraOpen ++ x ++ event
    }
  where
    regular = createICalEventsFromDefaultSchedules queryRoot (S.regular result) Q.Regular
    bankaraChallenge = createICalEventsFromDefaultSchedules queryRoot (S.bankaraChallenge result) Q.BankaraChallenge
    bankaraOpen = createICalEventsFromDefaultSchedules queryRoot (S.bankaraOpen result) Q.BankaraOpen
    x = createICalEventsFromDefaultSchedules queryRoot (S.x result) Q.XMatch
    event = createICalEventsFromEventMatches queryRoot (S.event result)
