module Calendar.EventViewer exposing (view)

import Html exposing (Html, div, pre, text, button, textarea, input, label, select, option, optgroup, span)
import Html.Attributes exposing (class, value, placeholder, style, disabled, type_, step, required, selected, attribute)
import Html.Events as HE

import Json.Encode as JE

import Calendar.DateTimeFormats exposing (..)
import Calendar exposing (..)

import Calendar.Timezones as Timezones exposing (Timezone)

import Utils exposing (..)

view : Event -> Html msg
view event = div
    [ class "cal-event-view" ]
    [ div
        [ class "dt-group" ]
        [ case event.end of
            Nothing -> label [] [ text "at" ]
            Just _  -> label [] [ text "from" ]
        , viewDT event.start
        ]
    , case event.end of
        Just end ->
            div
                [ class "dt-group" ]
                [ label [] [ text "to" ]
                , viewDT end
                ]
        Nothing -> text ""
    , case event.repeat of
        Nothing  -> text ""
        Just rep -> viewRepeat rep event.start
    , case event.reminders of
        [] -> text ""
        _  -> indicator "indicator-reminder" "has a reminder"
    ]

viewRepeat : Repeat -> DateTime -> Html msg
viewRepeat rep start = let txt = case rep.freq of
                                    Secondly -> "second"
                                    Minutely -> "minute"
                                    Hourly -> "hour"
                                    Daily -> "day"
                                    Weekly -> "week"
                                    Monthly -> "month"
                                    Yearly -> "year"
    in
        indicator "indicator-repeat" ("repeats every " ++ txt)



viewDT : DateTime -> Html msg
viewDT dt = text (dateTimeToHumanString dt)
