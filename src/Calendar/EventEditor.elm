module Calendar.EventEditor exposing (Model, Msg, init, update, view, getEvent)

import Html exposing (Html, div, pre, text, button, textarea, input, label, select, option)
import Html.Attributes exposing (class, value, placeholder, style, disabled, type_, checked, step, required, selected)
import Html.Events as HE

import Json.Encode as JE

import Calendar.DateTimeFormats exposing (..)
import Calendar exposing (..)

import Timezones exposing (Timezone)

type alias Model =
    { event: Event
    }

type Msg
    = Evil (Model -> Model)

init : Event -> Model
init evt = { event = evt }

getEvent : Model -> Event
getEvent { event } = event

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    Evil f -> (f model, Cmd.none)

view : Model -> Html Msg
view model = let event = model.event in div
    [ class "cal-event-editor" ]
    [ div
        [ class "start-end" ]
        [ label [] [ text "start: " ]
        , viewDTPicker event.start (\dt m -> { m | event = { event | start = dt } })
        ]
    ]

viewDTPicker : DateTime -> (DateTime -> Model -> Model) -> Html Msg
viewDTPicker dt f = div
    [ class "date-picker" ]
    [ input
        [ class "date", type_ "date", value (dateToValue dt), required True
        , HE.onInput (\v -> Evil (f (parseDatePart v dt)))] []
    , input
        [ class "time", type_ "time", value (timeToValue dt), step "1", required True
        , HE.onInput (\v -> Evil (f (parseTimePart v dt)))] []
    , viewTZPicker dt.timezone (\v -> f { dt | timezone = v })
    ]

viewTZPicker : Timezone -> (Timezone -> Model -> Model) -> Html Msg
viewTZPicker tz f =
    select
        [ class "timezone"
        , HE.onInput (\tzn -> case Timezones.fromString tzn of
            Just newTz -> Evil (f newTz)
            Nothing    -> Evil (f tz))
        ]
        (List.map (tzOption tz) Timezones.all)

tzOption : Timezone -> Timezone -> Html Msg
tzOption selectedTZ tz = let tzn = Timezones.toString tz in
    case tzn == Timezones.toString selectedTZ of
        True  -> option [ value tzn, selected True  ] [ text tzn ]
        False -> option [ value tzn, selected False ] [ text tzn ]
