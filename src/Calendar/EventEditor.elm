module Calendar.EventEditor exposing (Model, Msg, init, update, view, getEvent)

import Html exposing (Html, div, pre, text, button, textarea, input, label, select, option, optgroup, span)
import Html.Attributes exposing (class, value, placeholder, style, disabled, type_, step, required, selected, attribute, size)
import Html.Events as HE

import Json.Encode as JE

import Calendar.DateTimeFormats exposing (..)
import Calendar exposing (..)

import Calendar.Timezones as Timezones exposing (Timezone)

import Utils exposing (..)
import CommonComponents exposing (viewTZPicker)

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
    Evil f -> (fixup (f model), Cmd.none)

view : Model -> Html Msg
view model = let event = model.event in div
    [ class "cal-event-editor" ]
    [ div
        [ class "start-end" ]
        [ div
            [ class "dt-group" ]
            [ label [] [ text "at: " ]
            , viewDTPicker event.start (\dt m -> { m | event = { event | start = dt } })
            ]
        , div
            [ class "dt-group" ]
            [ label [] [ text "end: " ]
            , case event.end of
                Nothing ->
                    checkbox False
                        [ HE.onClick (Evil (\m -> { m | event = { event | end = Just event.start, kind = CalendarEvent } }))
                        ]
                        []
                Just end -> span []
                    [ checkbox True
                        [ HE.onClick (Evil (\m -> { m | event = { event | end = Nothing, kind = Task } }))
                        ] []
                    , viewDTPicker end (\dt m -> { m | event = { event | end = Just dt } })
                    ]
            ]
        , div
            [ class "dt-group" ]
            [ checkbox event.allDay
                [ onClick (Evil (\m -> { m | event = { event | allDay = not event.allDay } } ) )
                ]
                [ text "all day" ]
            , checkbox event.busy
                [ onClick (Evil (\m -> { m | event = { event | busy = not event.busy } } ) )
                ]
                [ text "treat as busy" ]
            , select
                [ HE.onInput (\k -> (Evil (\m -> { m | event = { event | kind = parseKind k event.kind } } ) ) )
                ]
                (List.map (kindOption model.event.kind) [ Task, CalendarEvent ])
            ]
        , div
            [ class "dt-group" ]
            [ checkbox (event.repeat /= Nothing)
                [ onClick (Evil (\m -> { m | event = { event | repeat =
                    case event.repeat of
                        Nothing -> Just defaultRepeat
                        Just _  -> Nothing } } ) )
                ]
                [ text "repeat" ]
            , case event.repeat of
                Nothing  -> text ""
                Just rep -> viewRepeatEditor event.start rep (\r m -> { m | event = { event | repeat = Just r } })
            ]
        , div
            [ class "reminder-list" ]
            ( ( case event.reminders of
                    [] -> []
                    _  ->
                        [ label [] [ text "reminders: " ]
                        , viewReminderEditors model
                        ]
            ) ++
            [ button
                [ class "calendar-event-btn"
                , class "add-reminder-btn"
                , onClick (Evil (\m -> { m | event = { event | reminders = defaultReminder :: event.reminders } })) ]
                [ text "add reminder" ]
            ])
        ]
    ]

fixup : Model -> Model
fixup model = let event = model.event in model
    |> (\m -> case m.event.allDay of
            True -> { m | event = { event | start = setTime (0, 0, 0) event.start
                                          , end = Maybe.map (setTime (23, 59, 59)) event.end } }
            False -> m)

viewRepeatEditor : DateTime -> Repeat -> (Repeat -> Model -> Model) -> Html Msg
viewRepeatEditor defaultDT rep f = div [ class "repeat-editor" ]
    [ text "every"
    , input
        [ type_ "number"
        , value (String.fromInt <| rep.interval)
        , size 3
        , HE.onInput (\v -> Evil (f (
            case String.toInt v of
                Nothing  -> rep
                Just int ->
                    case int <= 1 of
                        True  -> { rep | interval = 1 }
                        False -> { rep | interval = int }
            )))
        ] []
    , select
        [ HE.onInput (\fs -> Evil (f (case freqFromString fs of
            Nothing   -> rep
            Just freq -> { rep | freq = freq })))
        ]
        ( allFreqs |> List.map (\freq ->
            option [ value (freqToString freq), selected (freq == rep.freq) ]
                   [ text (freqPlural freq) ] ))
    , viewFilterSetPicker defaultDT rep.filterSet (\fs -> f { rep | filterSet = fs })
    ]

viewFilterSetPicker : DateTime -> FilterSet -> (FilterSet -> Model -> Model) -> Html Msg
viewFilterSetPicker defaultUntil fs f = div
    [ class "filter-set-picker" ]
    [ label [] [ text "only on:" ]
    , div [ class "weekdays" ] (allWeekdays |> List.map (\wd ->
        weekdayCheckbox fs f wd (List.member wd fs.weekdays) ))
    , div [ class "monthdays" ] (allMonthdays |> List.map (\wd ->
        monthdayCheckbox fs f wd (List.member wd fs.monthdays) ))
    , div [ class "months" ] (allMonths |> List.map (\wd ->
        monthCheckbox fs f wd (List.member wd fs.months) ))
    , div [ class "until" ]
        [ checkbox (fs.until /= Nothing)
            [ onClick (Evil (f { fs | until =
                case fs.until of
                    Nothing -> Just defaultUntil
                    Just _  -> Nothing } ) )
            ]
            [ text "until" ]
        , case fs.until of
            Nothing    -> text ""
            Just until -> viewDTPicker until (\newUntil -> f { fs | until = Just newUntil })
        ]
    , div [ class "maxCount" ]
        [ checkbox (fs.maxCount /= Nothing)
            [ onClick (Evil (f { fs | maxCount =
                case fs.maxCount of
                    Nothing -> Just 1
                    Just _  -> Nothing } ) )
            ]
            [ text "max count" ]
        , case fs.maxCount of
            Nothing    -> text ""
            Just maxCount ->
                input
                [ type_ "number"
                , value (String.fromInt maxCount)
                , size 3
                , HE.onInput (\v -> Evil (f (
                    case String.toInt v of
                        Nothing -> fs
                        Just n  ->
                            case n < 1 of
                                True  -> fs
                                False -> { fs | maxCount = Just n }
                    )))
                ] []
        ]
    ]

weekdayCheckbox : FilterSet -> (FilterSet -> Model -> Model) -> Weekday -> Bool -> Html Msg
weekdayCheckbox fs f wd checked = checkbox checked
    [ onClick (Evil (f { fs | weekdays = setMember wd (not checked) fs.weekdays }))
    ]
    [ text (weekdayToString wd) ]

monthdayCheckbox : FilterSet -> (FilterSet -> Model -> Model) -> Monthday -> Bool -> Html Msg
monthdayCheckbox fs f md checked = checkbox checked
    [ onClick (Evil (f { fs | monthdays = setMember md (not checked) fs.monthdays }))
    ]
    [ text (String.fromInt md) ]

monthCheckbox : FilterSet -> (FilterSet -> Model -> Model) -> Month -> Bool -> Html Msg
monthCheckbox fs f m checked = checkbox checked
    [ onClick (Evil (f { fs | months = setMember m (not checked) fs.months }))
    ]
    [ text (monthToString m) ]

viewReminderEditors : Model -> Html Msg
viewReminderEditors model = div [ class "reminder-editors" ]
    (List.indexedMap (viewReminderEditor model) model.event.reminders)

viewReminderEditor : Model -> Int -> Reminder-> Html Msg
viewReminderEditor model index rem = let event = model.event in div [ class "reminder-editor" ]
    [ indicator "indicator-reminder" "reminder"
    , viewSignedDurationPicker rem.trigger (\dur m -> setReminder m index { rem | trigger = dur })
    , viewReminderRepeatPicker rem.repeat  (\rep m -> setReminder m index { rem | repeat  = rep })
    , viewNoisinessPicker      rem.noisiness (\n m -> setReminder m index { rem | noisiness = n })
    , div [ class "spacer" ] []
    , button
        [ class "calendar-event-btn"
        , class "delete-reminder-btn"
        , onClick (Evil (\m -> { m | event = { event | reminders = event.reminders |> silentDelete index } })) ]
        [ text "delete" ]
    ]

setReminder : Model -> Int -> Reminder -> Model
setReminder model index rem = let event = model.event in
    { model | event = { event | reminders = silentUpdate index rem event.reminders } }

viewReminderRepeatPicker : ReminderRepeat -> (ReminderRepeat -> Model -> Model) -> Html Msg
viewReminderRepeatPicker rr f = div [ class "reminder-repeat-picker" ]
    [ text "repeat"
    , input
        [ type_ "number"
        , size 3
        , value (String.fromInt <| Calendar.timesOf rr)
        , HE.onInput (\v -> Evil (f (
            case String.toInt v of
                Nothing -> rr
                Just n  ->
                    case n <= 1 of
                        True  -> NoRepeat
                        False -> RepeatAt n (Calendar.intervalOf rr)
            )))
        ] []
    , case rr of
        NoRepeat -> span [] [ text "times" ]
        RepeatAt n int -> span []
            [ text "times, spaced at"
            , viewDurationPicker int (\dur -> f (RepeatAt n dur))
            ]
    ]

viewNoisinessPicker : Noisiness -> (Noisiness -> Model -> Model) -> Html Msg
viewNoisinessPicker n f = select
    [ class "noisiness-picker"
    , HE.onInput (\ns -> Evil (f (case ns of
        "noisy"  -> Noisy
        "silent" -> Silent
        _        -> Noisy
        )))
    ]
    [ option [ value "noisy",  selected (n == Noisy) ]  [ text "noisy" ]
    , option [ value "silent", selected (n == Silent) ] [ text "silent" ]
    ]

viewSignedDurationPicker : SignedDuration -> (SignedDuration -> Model -> Model) -> Html Msg
viewSignedDurationPicker dur f = div
    [ class "signed-duration-picker" ]
    [ case dur <= 0 of
        True  -> viewDurationPicker (0 - dur) (\newDur m -> f (0 - newDur) m)
        False -> viewDurationPicker    dur  (\newDur m -> f newDur    m)
    , case dur == 0 of
        True  -> text "at the moment of the event"
        False -> select
            [ class "duration-sign"
            , HE.onInput (\dsn -> Evil ( f (case dsn of
                "before" -> 0 - (abs dur)
                "after"  -> 0 + (abs dur)
                _        -> dur
                    )))
            ]
            [ option [ value "before", selected (dur < 0) ] [ text "Before" ]
            , option [ value "after",  selected (dur > 0) ] [ text "After"  ]
            ]
    ]

viewDurationPicker : Duration -> (Duration -> Model -> Model) -> Html Msg
viewDurationPicker dur f = div
    [ class "duration-picker" ]

    [ viewDurationMultiplePicker 86400     0  dur f, text "days"
    , viewDurationMultiplePicker 3600      24 dur f, text "hr"
    , viewDurationMultiplePicker 60        60 dur f, text "min"
    , viewDurationMultiplePicker 1         60 dur f, text "sec"
    ]

viewDurationMultiplePicker : Int -> Int -> Duration -> (Duration -> Model -> Model) -> Html Msg
viewDurationMultiplePicker quot rem dur f =
    let current = case rem of
                    0 ->            dur // quot
                    _ -> modBy rem (dur // quot)
    in input
        [ class "duration-multiple", type_ "number"
        , size 3
        , value (String.fromInt current)
        , HE.onInput (\v -> case String.toInt v of
            Just new -> Evil (f (dur - current * quot + new * quot))
            Nothing  -> Evil (f dur))
        ] []

viewDTPicker : DateTime -> (DateTime -> Model -> Model) -> Html Msg
viewDTPicker dt f = div
    [ class "date-picker" ]
    [ input
        [ class "date", type_ "date", value (dateToValue dt), required True
        , HE.onInput (\v -> Evil (f (parseDatePart v dt)))] []
    , input
        [ class "time", type_ "time", value (timeToValue dt), step "1", required True
        , HE.onInput (\v -> Evil (f (parseTimePart v dt)))] []
    , viewTZPicker dt.timezone (\v -> Evil (f { dt | timezone = v }))
    ]

parseKind : String -> Kind -> Kind
parseKind s k = Maybe.withDefault k (kindFromString s)

kindOption : Kind -> Kind -> Html Msg
kindOption selectedK k = option [ value (kindToString k), selected (k == selectedK) ] [ text (kindName k) ]

setTime : (Int, Int, Int) -> DateTime -> DateTime
setTime (h, m, s) dt = { dt | hour = h, minute = m, second = s }
