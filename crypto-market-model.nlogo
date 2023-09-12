;;Copyright by JackyGu 2023
globals [
  ;;By slider or input
  ;;initial-traders                ;;initial traders, not total traders
  ;;max-traders
  ;;ico-distribute-ratio
  ;;vesting-period
  ;;bullish-index           ;;1-10, 0 is bearish, 10 is bullish, 5 is balance
  ;;influence
  ;;show-scope
  ;;use-stop-loss
  ;;use-max-hold-days

  max-ticks         ;;max days
  total-amount      ;;total amount of tokens
  initial-price     ;;set 1
  last-price        ;;
  current-price     ;;
  gamma             ;;gamma for get price buy uniswap AMM
  influence-factor  ;;will be devided by random influence(0~100), less factor, more average influence. Suggest 2-9
  max-stop-loss
  kol-min-influence    ;;only the turtles which %influence not less than this number will be considered as kol
  %sell-on-stop-limit  ;;if the stop-limit was touched, buy immediately or wait
  %sell-on-stop-loss   ;;if the stop-loss was touched, sale immediately or wait
  %market-maker-rate
]

turtles-own [
  %influence            ;;influence power, to cover the circle of patches in radius
  %independent-mind     ;;independent mind, 0-100
  is-ico                ;;initial minter
  is-market-maker       ;;market maker traders are only buy, don't sell
  amount                ;;hold amount
  price                 ;;long price, ico price is 1
  buy-ticks             ;;when buy
  initial-cash          ;;initial cash
  cash                  ;;cash can use
  %stop-limit           ;;stop limit rate
  %stop-loss            ;;stop loss rate
  max-trade-times       ;;max trade times, if touch this, the trader will not trade any more
  trade-times           ;;
  checked-today         ;;
  max-hold-days         ;;after this period, the holder will sell
  total-assets          ;;cash + token value
  asset-change          ;;asset changed from the initial cash
]

to setup
  ca
  initialize-params
  ask patches [set pcolor white]
  setup-turtles
  output
  reset-ticks
end

to initialize-params
  ;;constant
  set initial-price 1
  set current-price 1
  set total-amount 100000000
  set gamma total-amount * %lp / 100     ;;0.5% of total-amount, otherwise the price change will be huge

  ;;========= variant =========
  set max-ticks 300
  set influence-factor 5
  set max-stop-loss 80
  set kol-min-influence 2
  set %sell-on-stop-loss 50
  set %sell-on-stop-limit 50
  set %market-maker-rate 0
  ;;=======================
end

to setup-turtles
  create-turtles initial-traders [
    set-turtle who true false true
  ]
end

to set-turtle [_who _isbuy _around-kol _initial]
  ask turtle _who [
    ifelse _around-kol
      [setxy xcor + (random 20 - 10) ycor + (random 20 - 10)]
      [setxy random-xcor random-ycor]
;    setxy random-xcor random-ycor
    set shape "person"
    set color gray + 2
    set size 3
;    set label-color black

    ;;set is-ico
    ifelse _initial [set is-ico true] [set is-ico false]

    ;;set affecting range according to %influence
    if show-scope [ask patches in-radius %influence [set pcolor yellow + 2]]
    set label who

    ;;set %influence for each trader by exponential distribution, 0 ~ 100/influence-factor
    ifelse influence [
      set %influence round ((random-exponential 5) / influence-factor)
    ] [
      set %influence 1
    ]

    ;;set %affected for eath trader by exponential distribution, 0-100
    set %independent-mind round (random-exponential 10)
    if %independent-mind > 100 [set %independent-mind 100]

    ;;set cash for eath trader by exponential amount, 500~100,000
    let _cash round (random-exponential 10) * 500 * new-cash-x
    set cash _cash
    set initial-cash _cash

    ;;set stop-limit and stop-loss for each trader
    set %stop-limit round (random-exponential 30) * 3
    ifelse use-stop-loss [
      set %stop-loss round (random-exponential 5)
      if %stop-loss > max-stop-loss [set %stop-loss max-stop-loss]
    ] [set %stop-loss 101]

    ;;set max-trade-times, 10-30
    set max-trade-times (floor (random (global-max-trade-times - 4)) + 5)

    ;;set max-hold-days
    ifelse use-max-hold-days [
      set max-hold-days round (random-exponential 10 + 0)
    ] [set max-hold-days 0]

    ;;allocatie the ico amount to random initial-traders
    ifelse _isbuy [
      let distribute-amount total-amount * ico-distribute-ratio / 100
      let average-amount floor (distribute-amount / initial-traders)
      set color green - 1                                      ;;set ico initial-traders
      set amount average-amount                                ;;allocate ico amount averagely
      set price initial-price                                  ;;set initial price as 1
    ] [
      set amount 0
      set price 0
    ]

    ;;set market maker
    set is-market-maker random 100 < %market-maker-rate
  ]
end

to go
  if ticks >= max-ticks [stop]
  if current-price <= 0 [stop]
  ask turtles [
    set checked-today false
  ]

  if debug [show (word "====== " ticks " ======")]

  ask turtles [
    ;;move
    let speed 1
    if %influence > 1 [set speed %influence / 3]                ;;more influence, more fast moving, divided 2 to slowdown
    rt random 70 lt random 70
    ask patches in-radius %influence [set pcolor white]         ;;set white patch
    fd speed                                                    ;;move by speed
    if show-scope [ask patches in-radius %influence [set pcolor yellow + 2]]    ;;set yellow patch

    if count turtles < max-traders [affect-new who]
    if %influence >= kol-min-influence [check-around who]

    set total-assets cash + amount * current-price
    if initial-cash > 0 [set asset-change (total-assets / initial-cash - 1) * 100]

;    if ticks mod 10 = 0 [set %influence %influence * (1 + asset-change / 1000)] ;;根据他的总盈利调整影响力
  ]

  ;;show [asset-change] of turtles
;  show (word "利润率分布 min " min [asset-change] of turtles " max " max [asset-change] of turtles)
  ;;random-price
  tick
end

;;方案2-
;;采取生成新的被影响的人，并在一定概率下购买。
;;被影响的人也可能是kol，没有买的会看空。
to affect-new [kol-turtle]
  ask turtle kol-turtle [
    if random 100 < bullish-index * 2 [    ;;possibility to affect new guys depends on bullish-index (0~20%)
      hatch %influence [
        set-turtle who false true false
      ]
    ]
  ]
end

;;方案1-
;;采取检查是否与周围人发生影响
to check-around [kol-turtle]
  ask turtle kol-turtle [
    ;;处理kol自己
    if not checked-today [
      ;;kol独立判断
      ifelse amount = 0 [
        if random 100 < bullish-index * 10 [
;          show word "现价 " current-price
          buy who
;          if debug [show (word who "- KOL自行：买入 @" current-price)]
        ]
      ] [
        if amount > 0
          and (random 100 < %sell-on-stop-limit and current-price > price * (1 + %stop-limit / 100)               ;;被影响者有货，且达到止盈或止损位
          or (random 100 < %sell-on-stop-loss and current-price < price * (1 - %stop-loss / 100))
          or (max-hold-days > 0 and ticks - buy-ticks > max-hold-days)) [
;            show word "现价 " current-price
            sell who
          if debug [show (word who "- KOL自行：止损/止盈卖出 @" current-price)]
          ]
      ]
      set checked-today true
    ]

    let kol-amount amount
    ask other turtles in-radius %influence [
      if not checked-today [
;        if debug [show (word "kol #" kol-turtle ", $" kol-amount " => #" who ", $" amount ", checked " checked-today ", 独立性 " %independent-mind)]
        ifelse amount > 0
          and (random 100 < %sell-on-stop-limit and current-price > price * (1 + %stop-limit / 100)
          or (random 100 < %sell-on-stop-loss and current-price < price * (1 - %stop-loss / 100))
          or (max-hold-days > 0 and ticks - buy-ticks > max-hold-days)) [
;          show word "现价 " current-price
          sell who
          if debug [show (word who "- 止损/止盈卖出 @" current-price)]
        ] [
          ifelse random 100 < %independent-mind [
;            if debug [show "被影响者独立判断"]
            ifelse amount = 0 [
              if random 100 < bullish-index * 10 [
;                show word "现价 " current-price
                buy who
;                if debug [show (word who "- 被影响者独立判断：买入 @" current-price)]
              ]
            ] [
              if amount > 0
                and (random 100 < %sell-on-stop-limit and current-price > price * (1 + %stop-limit / 100)                   ;;被影响者有货，且达到止盈或止损位
                or (random 100 < %sell-on-stop-loss and current-price < price * (1 - %stop-loss / 100))
                or (max-hold-days > 0 and ticks - buy-ticks > max-hold-days)) [
;                show word "现价 " current-price
                sell who
                if debug [show (word who "- 被影响者独立判断：止损/止盈卖出 @" current-price)]
              ]
            ]
          ] [
;            if debug [show "被影响者受KOL影响"]
            if kol-amount > 0 and amount = 0 [                                                 ;;kol有仓位，看多
              buy who
;                if debug [show (word who "- 受KOL影响：买入 @" current-price)]
            ]
            if kol-amount = 0 and amount > 0 [                                                                      ;;kol无仓位，说明看空
              if debug [show (word who "- 受KOL影响：卖出 " amount)]
              let pre-price price
              sell who
              if debug [show (word who "- 卖价 @" current-price ", 成本 " pre-price ", 盈亏 " (current-price - pre-price) ", 总资产 " total-assets ", 初始资金 " initial-cash)]
            ]
          ]
        ]
        set checked-today true
      ]
    ]
  ]
end

to sell [seller]
  ask turtle seller [
    if not is-market-maker [
      let _amount 0
      ifelse is-ico [set _amount (amount / vesting-period)] [set _amount amount]
      ;    if debug [show (word seller " 卖出数量 " _amount)]
      update-price false _amount
      set amount 0
      set price 0
      set cash cash + _amount * current-price
      set buy-ticks 99999
      set color gray + 2
      set trade-times trade-times + 1
    ]
  ]
end

to buy [buyer]
  ask turtle buyer [
    ifelse trade-times < max-trade-times [                                       ;;if trader don't want to trade
      let _amount (floor (cash / current-price)) ;;use 100% of cash
      if _amount > 0 [
;        if debug [show (word buyer " 买入数量 " _amount)]
        update-price true _amount
        set amount _amount
        set price current-price
        set cash cash - (_amount * current-price)
        set buy-ticks ticks
        set color green - 1
        set trade-times trade-times + 1
      ]
    ] [
      die
      ask patches in-radius %influence [set pcolor white]
    ]
  ]
end

;;testing for random price according to bullish index
to random-price
  update-price (random 10 < bullish-index) (random (10000 - 500) + 500)
end

;;get price according to uniswap AMM
to update-price [is-buy trade-amount]
  set last-price current-price
  ifelse not is-buy [
    set current-price gamma * (1 - gamma / (gamma + trade-amount)) * current-price / trade-amount
  ] [
    set current-price gamma * (gamma / (gamma - trade-amount) - 1) * current-price / trade-amount
  ]
end

to output
  show "============= TRADERS ============="
  show (word "total " turtles " traders")
  show (word "%influence ->        " (max [%influence] of turtles) " " (min [%influence] of turtles))
  show (word "%independent-mind -> " (max [%independent-mind] of turtles) " " (min [%independent-mind] of turtles))
  show (word "cash ->              " (max [cash] of turtles) " " (min [cash] of turtles))
  show (word "amount ->            " (max [amount] of turtles) " " (min [amount] of turtles))
  show (word "price ->             " (max [price] of turtles) " " (min [price] of turtles))
  show (word "%stop-limit ->       " (max [%stop-limit] of turtles) "% " (min [%stop-limit] of turtles) "%")
  show (word "%stop-loss ->        " (max [%stop-loss] of turtles) "% " (min [%stop-loss] of turtles) "%")
  show (word "max-trade-times ->   " (max [max-trade-times] of turtles) " " (min [max-trade-times] of turtles))

  ;;draw [%influence] of turtles
  ;;test-random
end

;; TODO
;; *价格暴跌的原因：止损踩踏
;; *取消stop-loss
;; *考虑最大持仓天数忍耐度
;; *根据asset-change 调整影响力
;; *加入只买不卖的控盘资金，看能否止住止损盘
;; *更灵活的 stop-limit & stop-loss
;; *增加资金量
;; 采用更实际的LP
;; 模拟FTO模式

;; 显示成交量
;; *显示持有人数
;; 显示交易后筹码集中度

;; 结论：
;; 1- 社区资源的上线到达后，价格会增长乏力，如果没有新的社区进来，很快会踩踏暴跌。价格能突破第一次高点的唯一可能性是新社区。
;;    一开始社区小，没关系，只要后续一层一层有计划进来，就能不断创新高。
;; 2- 理论上，暴跌后，完全有再次上涨的可能，取决于重建被破坏的共识和信任，难度在于大多数人不会再玩
;; 所以：零和游戏的运营关键是在共识坍塌前，引入新的社区，一轮一轮接力棒。除非有基本面支持并回购（即只买不卖）
;;
;; 3- 早期ico如果不锁仓，或释放不科学，会成为快速崩盘的唯一原因。
;; 4- 熊市和牛市的规律一样，区别在于熊市里新社区扩建难度高，价格到顶后暴跌更频繁，新人不进，即使牛市也没用。很多项目在牛市没有任何表现，就是这个原因。
;; 5- 流动池占总发行量比例越高，价格波动越小
;; 6- 只要发行（铸造）公平，且经济模型契合，第一波赚钱确定性高
;; 7- KOL的平均影响力越大，价格波动越大。
;; 8- 每次重启的新增资金对是否冲高有很大影响。（与人数只要具备其一即可）
@#$#@#$#@
GRAPHICS-WINDOW
315
230
893
809
-1
-1
4.043
1
10
1
1
1
0
1
1
1
-70
70
-70
70
0
0
1
ticks
30.0

BUTTON
15
50
100
83
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
50
210
83
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
220
50
310
83
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
95
310
128
initial-traders
initial-traders
1
200
1.0
1
1
NIL
HORIZONTAL

PLOT
315
55
695
230
Current price
time
price
0.0
10.0
0.7
1.3
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot current-price"

SLIDER
15
175
310
208
ico-distribute-ratio
ico-distribute-ratio
0
100
0.0
1
1
%
HORIZONTAL

SLIDER
15
255
310
288
bullish-index
bullish-index
1
9
5.0
1
1
NIL
HORIZONTAL

MONITOR
315
10
412
55
NIL
current-price
3
1
11

SLIDER
15
135
310
168
max-traders
max-traders
50
5000
2750.0
50
1
NIL
HORIZONTAL

MONITOR
410
10
497
55
total traders
count turtles
1
1
11

SWITCH
15
10
105
43
debug
debug
1
1
-1000

PLOT
15
465
310
640
Asset change %
asset change%
times
0.0
1.0
-200.0
200.0
false
false
"set-histogram-num-bars 9" "set-plot-x-range -100 500\nset-plot-y-range 0 20"
PENS
"default" 1.0 0 -8053223 true "" "histogram [asset-change] of turtles"

SWITCH
15
380
160
413
influence
influence
0
1
-1000

SLIDER
15
215
310
248
vesting-period
vesting-period
1
360
1.0
1
1
NIL
HORIZONTAL

SWITCH
15
420
160
453
use-stop-loss
use-stop-loss
0
1
-1000

SWITCH
170
420
310
453
use-max-hold-days
use-max-hold-days
1
1
-1000

SLIDER
15
295
310
328
global-max-trade-times
global-max-trade-times
5
50
13.0
1
1
NIL
HORIZONTAL

PLOT
15
645
310
810
Access
NIL
NIL
0.0
10.0
0.0
10.0
false
false
"set-histogram-num-bars 20" "set-plot-x-range 0 50000\nset-plot-y-range 0 100"
PENS
"default" 1.0 0 -16777216 true "" "histogram [total-assets] of turtles"

SWITCH
170
380
310
413
show-scope
show-scope
1
1
-1000

TEXTBOX
120
10
265
46
Zero-sum game market modeling (ver 0.1)
12
0.0
1

SLIDER
15
335
160
368
%lp
%lp
0.5
100
0.5
0.5
1
%
HORIZONTAL

SLIDER
170
335
310
368
new-cash-x
new-cash-x
1
10
8.0
1
1
x
HORIZONTAL

PLOT
695
55
895
230
holders
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [color = green - 1]"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
