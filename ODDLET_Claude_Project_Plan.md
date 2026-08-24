# ODDLET --- Claude 개발용 프로젝트 기획서

> 문서 목적: Claude Code가 이 문서를 프로젝트의 기준 기획서(Source of
> Truth)로 사용하여 MVP를 설계·구현할 수 있도록 한다.\
> 상태: MVP Draft v0.1\
> 기준일: 2026-08-24

------------------------------------------------------------------------

## 0. Claude에게 전달하는 최우선 지침

이 프로젝트는 **기능이 많은 모바일 게임을 만드는 프로젝트가 아니다.**

핵심은 아래 한 문장이다.

> **같은 알을 받은 사용자들이 현실에서 스마트폰을 어떻게 사용했는지에
> 따라 서로 다른 생명체를 발견하는 수집형 디지털 토이 앱.**

개발 중 새로운 기능을 추가하고 싶어지더라도 아래 핵심 루프를 강화하지
않는 기능은 MVP에서 제외한다.

``` text
알 획득
→ 현실 행동
→ 숨겨진 조건 판정
→ 부화
→ 예상하지 못한 결과 발견
→ 도감 등록
→ 공유 또는 다음 날 재도전
```

### 절대 지켜야 할 원칙

1.  MVP는 1인 개발 가능한 범위로 유지한다.
2.  친구/채팅/길드/거래/실시간 멀티플레이는 구현하지 않는다.
3.  유료 확률형 가챠를 구현하지 않는다.
4.  AI 생성 기능을 핵심 기능으로 사용하지 않는다.
5.  사용자가 모든 조건을 UI에서 확인할 수 있게 만들지 않는다.
6.  `발견`, `추측`, `수집`이 핵심 재미다.
7.  복잡한 시스템보다 앱의 촉감, 애니메이션, 사운드, 부화 순간을
    중요하게 취급한다.
8.  기능 하나를 완성할 때마다 테스트 → 검증 → 커밋 가능한 상태로 만든다.
9.  검증되지 않은 기능 위에 다음 기능을 쌓지 않는다.
10. MVP 이후 기능은 TODO/ROADMAP으로 분리하고 현재 구현에 섞지 않는다.

------------------------------------------------------------------------

# 1. 프로젝트 정의

## 1.1 프로젝트명

임시 프로젝트명:

**ODDLET**

정식 서비스명은 출시 전에 변경될 수 있으므로 코드 내부에서 서비스명을
과도하게 하드코딩하지 않는다.

## 1.2 브랜드 / 세계관 용어

-   앱/브랜드명: **ODDLET**
-   한국어 표기: **오들렛**
-   세계관 속 수집 생명체 총칭: **Oddlets**
-   메인 카피: **What will yours become?**
-   보조 카피: **Discover something odd.**
-   Season 01: **EGG**
-   Season 02: **SEED**
-   Season 03: **STONE**

`Oddlet`은 단순히 알에서 태어나는 캐릭터를 의미하지 않는다. 시즌마다 알,
씨앗, 돌 등 서로 다른 정체불명의 오브젝트를 통해 발견되는 존재 전체를
포괄하는 세계관 용어로 사용한다.

## 1.3 장르

-   Digital Toy
-   Mystery Collection
-   Casual Game-like App
-   Daily Collection

일반적인 모바일 게임보다는 **매일 열어보는 디지털 장난감**에 가깝다.

## 1.4 플랫폼

MVP:

-   Android
-   iOS

권장 프레임워크:

-   Flutter
-   Dart

## 1.5 핵심 타깃

주요 타깃:

-   10\~30대
-   가챠/수집 요소를 좋아하는 사용자
-   짧게 접속하는 캐주얼 콘텐츠를 선호하는 사용자
-   희귀 아이템/도감 완성을 좋아하는 사용자
-   SNS/커뮤니티에 재미있는 결과를 공유하는 사용자

------------------------------------------------------------------------

# 2. 핵심 콘셉트

Season 01의 테마는 **EGG**다.

모든 사용자는 하루에 하나의 알을 받는다.

알의 겉모습은 날짜에서 뽑은 시드로 매일 다르게 생성된다. 색과 표면 무늬가
달라지지만 **겉모습은 결과와 아무 관련이 없다.**

> 변경 이력: 초안은 "알 자체는 기본적으로 동일하다"였으나 날짜 기반 랜덤
> 외형으로 변경(2026-08-24).
> 사유 --- 매일 같은 알이면 하루하루가 구분되지 않는다. 시드가 날짜에서
> 나오므로 오늘 알은 하루 종일 같은 모습이고, 같은 날 모든 사용자가 같은
> 알을 받는다. 앱을 켤 때마다 색이 바뀌면 물건이 아니라 화면이 된다.
>
> 주의 --- 사용자가 겉모습과 결과의 상관관계를 추측하는 것은 자연스럽고
> 막지 않는다. 다만 실제로 연동하지는 않는다. 겉모습을 조건에 넣으면
> 사용자가 통제할 수 없는 변수가 되어 행동 기반 구조가 무너진다.

하지만 알을 가지고 있는 동안 사용자가 현실에서 한 행동이 기록된다.

예:

-   알을 터치한다.
-   스마트폰을 흔든다.
-   걸어 다닌다.
-   특정 시간까지 기다린다.
-   특정 시간에 부화한다.
-   충전하면서 보관한다.
-   배터리가 거의 없는 상태에서 부화한다.

이 행동값들을 기반으로 알의 최종 결과가 결정된다.

예:

``` text
아무것도 하지 않음
→ 평범한 병아리

100회 이상 흔듦
→ 어지러운 병아리

1,000회 이상 터치
→ 화난 병아리

10,000보 이상 걸음
→ 운동광 병아리

03:00~04:00 사이 부화
→ 유령 병아리

10,000보 + 새벽 부화
→ EPIC 변종

특정 행동 조합 + 낮은 확률
→ SECRET
```

중요:

**사용자에게 정확한 획득 조건을 알려주지 않는다.**

사용자는 결과를 보고 조건을 추측해야 한다.

------------------------------------------------------------------------

# 3. 핵심 재미

이 프로젝트에서 가챠의 재미는 버튼을 눌러 랜덤 결과를 받는 것이 아니다.

다음 구조가 핵심이다.

``` text
Mystery
+
Real-world Action
+
Hidden Conditions
+
Collection
+
Discovery
```

사용자가 느껴야 하는 감정:

> "나는 이게 나왔는데?"

> "왜 친구는 다른 게 나왔지?"

> "이거 어떻게 얻는 거야?"

> "혹시 새벽에 열어서 그런가?"

> "이번에는 다른 방법으로 해봐야겠다."

따라서 결과를 완전히 랜덤으로 만들지 않는다.

**행동 기반 결정 + 일부 확률** 구조를 사용한다.

------------------------------------------------------------------------

# 4. MVP 핵심 루프

## STEP 1 --- Daily Egg

하루에 기본 EGG 1개 지급.

앱 실행 시 오늘의 알이 없다면 지급한다.

서버 시간을 기준으로 하루를 판단한다.

------------------------------------------------------------------------

## STEP 2 --- Interaction

알이 존재하는 동안 사용자 행동을 기록한다.

MVP에서 우선 지원:

-   Touch Count
-   Shake Count
-   Step Count
-   Current Time / Hatch Time
-   Battery Level
-   Charging State

센서 권한이나 OS 정책 때문에 구현 복잡도가 지나치게 높아지는 값은 제거할
수 있다.

------------------------------------------------------------------------

## STEP 3 --- Egg State

알은 사용자의 행동에 따라 미세하게 반응한다.

예:

-   흔들면 움직임
-   터치하면 진동/소리
-   특정 임계치 이후 작은 금
-   부화 시간이 가까워지면 움직임 증가

단,

**어떤 결과가 나올지는 알려주지 않는다.**

------------------------------------------------------------------------

## STEP 4 --- Hatch

부화 가능 시간이 되면 사용자가 직접 부화시킨다.

권장 연출:

``` text
알 흔들림
→ 금이 생김
→ 화면/진동 피드백
→ 알 깨짐
→ 잠깐 암전 또는 플래시
→ 캐릭터 등장
→ 희귀도 표시
→ NEW 표시
```

이 순간이 앱에서 가장 중요한 UX다.

기능 구현보다 부화 연출 품질을 우선한다.

------------------------------------------------------------------------

## STEP 5 --- Collection

획득한 캐릭터는 Collection에 등록한다.

예:

``` text
EGG COLLECTION

COMMON
[획득] [획득] [???] [획득]

UNCOMMON
[???] [획득] [???]

RARE
[획득] [???] [???]

EPIC
[???] [???]

LEGENDARY
[???]

SECRET
[????????]
```

미발견 캐릭터는 실루엣 또는 `???` 처리한다.

SECRET은 이름이나 전체 개수를 숨기는 것도 가능하다.

------------------------------------------------------------------------

## STEP 6 --- Share

획득 결과를 이미지 카드 형태로 공유할 수 있다.

권장 비율:

-   9:16

포함 정보:

-   캐릭터
-   캐릭터 이름
-   희귀도
-   NEW 여부
-   발견 번호 또는 날짜
-   ODDLET 로고

포함하지 않는 정보:

-   정확한 획득 조건

------------------------------------------------------------------------

# 5. Season 01 콘텐츠

MVP에서는 **30종**을 목표로 한다.

초기 프로토타입에서는 8\~10종만 구현하여 핵심 재미를 먼저 검증한다.

## 최종 MVP 목표

  Rarity         Count
  ----------- --------
  COMMON            10
  UNCOMMON           7
  RARE               6
  EPIC               4
  LEGENDARY          2
  SECRET             1
  **TOTAL**     **30**

------------------------------------------------------------------------

# 6. 결과 판정 시스템

결과 판정은 데이터 기반으로 설계한다.

캐릭터마다 코드를 직접 분기문에 하드코딩하지 않는다.

예시 개념:

``` yaml
id: ghost_chick
rarity: RARE

conditions:
  hatch_time:
    from: "03:00"
    to: "04:00"

weight: 100
priority: 30
```

복합 조건 예:

``` yaml
id: dawn_runner
rarity: EPIC

conditions:
  min_steps: 10000
  hatch_time:
    from: "04:00"
    to: "06:00"

weight: 20
priority: 80
```

Claude는 실제 구현 시 적절한 JSON/Firestore 구조로 변경할 수 있다.

### 판정 원칙

1.  조건을 만족하는 후보를 검색한다.
2.  priority가 높은 특수 조건을 우선한다.
3.  동일 priority 후보가 여러 개면 weight를 사용한다.
4.  어떤 특수 조건도 충족하지 않으면 COMMON fallback 결과를 반환한다.
5.  사용자는 반드시 하나의 결과를 얻어야 한다.

------------------------------------------------------------------------

# 7. 행동 데이터

Daily Egg마다 다음과 같은 데이터를 저장할 수 있다.

``` text
eggId
date
createdAt

touchCount
shakeCount
stepCount

initialBattery
hatchBattery
chargingDuration 또는 chargingState

hatchTime

resultCreatureId
hatchedAt
```

불필요한 개인정보는 저장하지 않는다.

------------------------------------------------------------------------

# 8. 주요 화면

MVP 화면은 최대한 적게 유지한다.

## 8.1 Splash

-   로고
-   최소 로딩

## 8.2 Home / Egg

가장 중요한 화면.

표시:

-   현재 알
-   알 애니메이션
-   부화 가능 여부
-   필요할 경우 남은 시간

지나치게 많은 수치/버튼을 노출하지 않는다.

사용자는 알 자체를 만지고 싶어야 한다.

## 8.3 Hatch

부화 전용 연출 화면.

## 8.4 Result

표시:

``` text
NEW!

GHOST CHICK

RARE

[COLLECTION]

[SHARE]
```

## 8.5 Collection

전체 도감.

필터:

-   ALL
-   COMMON
-   UNCOMMON
-   RARE
-   EPIC
-   LEGENDARY

SECRET 처리 방식은 별도 UX 검토.

## 8.6 Creature Detail

-   Sprite
-   Name
-   Rarity
-   First Discovered
-   Obtain Count
-   Flavor Text

정확한 획득 조건은 표시하지 않는다.

## 8.7 Settings

최소 구성:

-   Sound
-   Vibration
-   Notification
-   Permissions
-   Account/Data
-   Privacy
-   App Version

------------------------------------------------------------------------

# 9. 아트 방향

방향:

**3D 렌더링 기반**

> 변경 이력: 초안은 픽셀아트 기반이었으나 3D로 변경(2026-08-24).
> 사유 --- 알을 직접 만지고 돌려보는 촉감이 이 앱의 핵심 UX인데,
> 2D 스프라이트로는 드래그 시점 변경과 조명 반응을 표현할 수 없다.

### 알 (Egg)

알은 회전체이므로 **fragment shader 레이마칭**으로 실시간 렌더링한다.

-   모델 파일 불필요, 에셋 0개
-   실시간 조명 / 법선 / 시점 회전
-   부화 시 금·발광·파편 연출을 같은 셰이더에서 확장 가능

사용자는 알을 드래그해서 시점을 바꿀 수 있다.

### 캐릭터 (Creature)

캐릭터는 회전체가 아니므로 셰이더로 표현할 수 없다.

렌더링 방식은 TASK-008 전까지 결정한다. 후보:

-   glTF 실시간 렌더링
-   Blender 프리렌더 턴테이블 시퀀스 (드래그로 프레임 스크럽)

두 방식 모두 알 셰이더와 공존 가능하므로 지금 결정하지 않는다.

### 필수

프리렌더 이미지를 사용할 경우 배경은:

**완전 투명 PNG (alpha 0)**

### 애니메이션 제작량 통제

캐릭터당 애니메이션을 과도하게 만들지 않는다.

MVP:

-   Idle 1종
-   Hatch 등장 1종

공통 부화 효과는 재사용한다.

------------------------------------------------------------------------

# 10. 사운드

사운드는 작은 디지털 장난감을 만지는 느낌을 강화해야 한다.

필요:

-   Egg Touch
-   Egg Shake
-   Crack
-   Hatch
-   COMMON Result
-   RARE Result
-   EPIC Result
-   LEGENDARY Result
-   SECRET Result

희귀도가 높을수록 연출 차이를 명확하게 한다.

------------------------------------------------------------------------

# 11. 바이럴 구조

MVP에서 강제 친구 초대 기능을 만들지 않는다.

바이럴은 **발견 결과**에서 발생해야 한다.

목표 상황:

``` text
사용자 A:
"이거 나왔는데 뭐임?"

사용자 B:
"어떻게 얻었어?"

A:
"모르겠는데 어제 폰 엄청 흔들긴 함"

B:
앱 설치 → 같은 행동 시도
```

따라서 공유 카드에는 획득 조건을 적지 않는다.

SECRET/LEGENDARY는 공유하고 싶을 정도로 시각적 차이를 둔다.

------------------------------------------------------------------------

# 12. 리텐션

## Daily Egg

기본 하루 1개.

사용자가 무한 반복해서 하루 만에 도감을 완성할 수 없게 한다.

## Collection Gap

미발견 슬롯이 계속 보이게 한다.

## Hidden Conditions

다음 날 다른 행동을 시도할 이유를 만든다.

## Notification

예:

``` text
Your egg is ready.
```

또는

``` text
Something is moving inside...
```

과도한 푸시는 금지.

------------------------------------------------------------------------

# 13. 수익화

MVP의 최우선 목표는 수익이 아니라:

-   Retention
-   Hatch Completion
-   Collection Engagement
-   Share Rate

검증이다.

### 가능한 초기 수익화

#### Rewarded Ad

광고를 보면 추가 EGG 1개.

일일 제한 필요.

예:

``` text
Daily Egg: 1
Reward Ad Bonus: +1
Maximum: 2 Eggs / Day
```

#### Remove Ads

일회성 광고 제거.

### 이후 검토

-   과거 시즌 이용권
-   Showcase 꾸미기
-   Egg Skin
-   Collection Background
-   Cosmetic Effect

### 하지 않을 것

-   돈으로 직접 랜덤 캐릭터 구매
-   Pay-to-Win
-   현금성 아이템 거래

------------------------------------------------------------------------

# 14. 기술 스택

## Client

``` text
Flutter
Dart
```

상태관리:

``` text
Riverpod
```

를 우선 검토한다.

## Backend

Firebase 권장.

### Firebase Authentication

Anonymous Authentication.

사용자가 회원가입 화면을 거치지 않고 시작하도록 한다.

향후 필요하면:

-   Apple
-   Google

계정 연결.

### Firestore

저장 대상:

-   User
-   Daily Egg
-   Collection
-   Season
-   Creature Definition
-   Rule Version

### Firebase Analytics

필수 이벤트 예:

``` text
app_open
egg_claim
egg_touch
egg_hatch_start
egg_hatch_complete
new_creature
rare_creature
collection_open
share_result
reward_ad_complete
```

단 `egg_touch`는 모든 터치를 원격 이벤트로 보내지 말고 로컬 누적 후
필요한 형태로 집계한다.

### Crashlytics

MVP부터 적용.

### FCM

부화/일일 알 알림.

------------------------------------------------------------------------

# 15. 데이터 모델 초안

``` text
users/{uid}

createdAt
currentSeasonId
lastEggClaimDate
```

``` text
users/{uid}/dailyEggs/{date}

eggId
createdAt

touchCount
shakeCount
stepCount

hatchTime
resultCreatureId
hatchedAt
```

``` text
users/{uid}/collection/{creatureId}

firstObtainedAt
lastObtainedAt
count
```

``` text
seasons/{seasonId}

name
startAt
endAt
ruleVersion
```

``` text
creatures/{creatureId}

seasonId
name
rarity
assetKey
description
hidden
```

실제 구조는 구현 과정에서 최적화 가능하지만, 변경 이유를 문서화한다.

------------------------------------------------------------------------

# 16. 부정행위 대응

MVP에서 완벽한 안티치트는 목표가 아니다.

그러나 아래는 지킨다.

### 서버 시간 사용

다음에 기기 시간을 신뢰하지 않는다.

-   Daily Egg 지급
-   시즌 기간
-   시간 기반 조건의 중요한 판정

### 비정상 값 검증

예:

``` text
shakeCount = 999999999
steps = 5000000
```

등은 제한한다.

### 결과 판정

가능하면 최종 결과는 신뢰 가능한 로직에서 판정한다.

단, 서버 비용/복잡도를 지나치게 증가시키지 않는다.

현재 MVP에는:

-   PvP 없음
-   거래 없음
-   현금가치 없음

따라서 안티치트보다 재미 검증이 우선이다.

------------------------------------------------------------------------

# 17. MVP에서 절대 구현하지 않을 기능

다음 기능은 요청이 별도로 승인되지 않는 이상 MVP에 추가하지 않는다.

``` text
Friend
Follow
Chat
Guild
Trading
Marketplace
PvP
Real-time Ranking
AI Character Generation
User Generated Character
GPS Quest
Weather Quest
Clan
Battle Pass
Paid Gacha
Complex Inventory
Equipment
Combat
```

ODDLET을 RPG로 만들지 않는다.

------------------------------------------------------------------------

# 18. 개발 전략

이 프로젝트는 **기능 루프 개발 방식**으로 진행한다.

하나의 기능을 완성하고 검증한 뒤 다음 기능으로 이동한다.

권장 흐름:

``` text
Task 선정

↓

구현

↓

Build

↓

Test

↓

문제 수정

↓

Acceptance Criteria 확인

↓

Commit

↓

다음 Task
```

큰 기능 여러 개를 동시에 구현하지 않는다.

------------------------------------------------------------------------

# 19. 개발 단계

## PHASE 0 --- Prototype

목표:

**이 아이디어 자체가 재미있는지 확인**

구현:

-   Egg 화면
-   Touch
-   Shake
-   간단한 결과 판정
-   8\~10개 Creature
-   Hatch Animation
-   Collection

Backend 없이 Local Prototype도 가능.

### 완료 조건

실제 사용자가:

> "다른 방법으로 하면 뭐 나오지?"

라는 반응을 보이는지 확인.

이 반응이 없다면 서버 개발 전에 핵심 루프를 수정한다.

------------------------------------------------------------------------

## PHASE 1 --- Core MVP

구현:

-   Flutter Project Architecture
-   Anonymous Auth
-   Daily Egg
-   Interaction Tracking
-   Hatch
-   Result Rule Engine
-   Collection
-   Local/Cloud Save

------------------------------------------------------------------------

## PHASE 2 --- Content

-   30 Creatures
-   Rarity
-   Flavor Text
-   Sprite
-   Hatch Effect
-   Result Effects

------------------------------------------------------------------------

## PHASE 3 --- Retention

-   Notification
-   Daily Reset
-   Collection Completion
-   Duplicate Count

------------------------------------------------------------------------

## PHASE 4 --- Viral

-   Share Card
-   SECRET Share
-   Deep Link / Store Link

------------------------------------------------------------------------

## PHASE 5 --- Monetization

핵심 지표 확인 후:

-   Reward Ad
-   Remove Ads

------------------------------------------------------------------------

# 20. 예상 개발 기간

1인 개발 + AI 코딩 보조 기준 목표:

``` text
Prototype: 1~2주

Core MVP: 3~4주

Content / Art: 2~3주

QA / Polish: 1~2주

Store Release: 1주+
```

전체:

**약 8\~12주**

단, 일정 맞추기보다 기능 단위 검증을 우선한다.

------------------------------------------------------------------------

# 21. 핵심 KPI

출시 후 우선 확인:

## D1 Retention

목표 가설:

``` text
35%+
```

## D7 Retention

목표 가설:

``` text
12~20%+
```

## Hatch Completion

알을 받은 사용자가 실제 부화까지 진행하는 비율.

목표:

``` text
70%+
```

## Share Rate

결과 획득 후 공유.

초기 목표:

``` text
5~10%+
```

## Rare Share Rate

RARE 이상 결과가 COMMON보다 유의미하게 더 많이 공유되는지 확인.

------------------------------------------------------------------------

# 22. Season 확장

코어 시스템은 시즌마다 재사용한다.

## Season 01

``` text
EGG
```

알 → 생명체.

## Season 02

``` text
SEED
```

씨앗 → 식물/버섯/이상한 생명체.

## Season 03

``` text
STONE
```

돌 → 광석/화석/생명체/정체불명 물체.

## Season 04

미정.

시즌마다 입력 시스템 일부를 추가할 수 있지만 기존 코어를 깨지 않는다.

------------------------------------------------------------------------

# 23. 장기 확장 후보

MVP 성공 이후에만 검토한다.

### World First Discovery

누군가 새로운 SECRET을 세계 최초 발견.

``` text
WORLD FIRST

Creature #042

First discovered by
XXXX

2027.01.03 03:17
```

### Friend Showcase

친구의 대표 캐릭터만 구경.

### Collection Showcase

자신의 희귀 캐릭터 진열.

### Trading

유저 규모가 충분히 커지고 경제 설계가 가능한 단계에서만 검토.

------------------------------------------------------------------------

# 24. 성공 조건

ODDLET의 성공 여부는 기능 수로 판단하지 않는다.

사용자가 다음 행동을 하는지가 중요하다.

``` text
1. 오늘 알을 받는다.

2. 뭔가 해본다.

3. 예상하지 못한 결과가 나온다.

4. 도감의 빈칸을 본다.

5. 다른 조건을 추측한다.

6. 내일 다시 들어온다.
```

그리고 가장 강한 성공 신호는 이것이다.

> **사용자들이 앱 밖에서 획득 방법을 서로 추측하기 시작한다.**

커뮤니티에서:

``` text
"이거 어떻게 얻음?"

"새벽에 부화해봐."

"아닌데 난 그렇게 했는데 안 나옴."

"걸음 수도 조건인 듯?"

"SECRET 발견한 사람 있음?"
```

같은 대화가 자연스럽게 발생하면 핵심 구조가 작동하고 있는 것이다.

------------------------------------------------------------------------

# 25. Claude 작업 규칙

Claude Code는 개발 중 다음 규칙을 따른다.

## 작업 시작 전

1.  이 문서를 읽는다.
2.  현재 Task를 명확히 정의한다.
3.  관련 기존 코드를 먼저 확인한다.
4.  필요 이상의 리팩터링을 하지 않는다.

## 구현 중

1.  현재 Task 범위를 벗어나지 않는다.
2.  미래 기능을 미리 구현하지 않는다.
3.  임시 코드가 필요하면 명확한 TODO를 남긴다.
4.  플랫폼별 동작 차이를 고려한다.
5.  센서/권한 기능은 실제 디바이스 검증 방법까지 제시한다.

## 작업 완료 후

반드시 아래 내용을 보고한다.

``` text
[Task Result]

Task:
구현한 기능

Changed:
변경 파일

Implementation:
구현 내용

Test:
실행한 테스트

Result:
PASS / FAIL

Known Issues:
알려진 문제

Manual Test:
사용자가 직접 확인할 항목

Next:
다음 권장 Task
```

Acceptance Criteria를 충족하지 못하면 완료로 처리하지 않는다.

------------------------------------------------------------------------

# 26. 최초 개발 순서

Claude가 프로젝트를 처음 생성한다면 아래 순서를 우선한다.

``` text
TASK-001
Flutter 프로젝트 기본 구조

TASK-002
Home Egg 화면

TASK-003
Egg Touch Interaction

TASK-004
Shake Sensor

TASK-005
Local Daily Egg State

TASK-006
Local Rule Engine

TASK-007
Hatch Animation

TASK-008
Creature Result

TASK-009
Collection

TASK-010
8~10종 Prototype Content

TASK-011
Prototype QA

------------------------------

여기까지 검증 후 Firebase 작업 시작

------------------------------

TASK-012
Firebase Setup

TASK-013
Anonymous Authentication

TASK-014
Cloud Daily Egg

TASK-015
Cloud Collection

TASK-016
Server Time

TASK-017
Analytics

...
```

**Prototype 재미 검증 전에 백엔드와 운영 기능부터 만들지 않는다.**

------------------------------------------------------------------------

# 27. 최종 제품 정의

> **ODDLET은 돈으로 캐릭터를 뽑는 가챠 게임이 아니다.**

> **사용자의 현실 행동이 숨겨진 입력값이 되어 결과를 발견하는 디지털
> 장난감이다.**

모든 기능 결정은 아래 질문으로 판단한다.

> **"이 기능이 발견하고 싶다는 감정을 더 강하게 만드는가?"**

YES라면 검토한다.

NO라면 MVP에서 제외한다.
