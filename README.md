# AquaTime 💧 — напоминалка пить воду (iOS 17+, SwiftUI)

## Как запустить
1. Нужен Mac с Xcode 15+.
2. Вариант А (быстро): `brew install xcodegen && xcodegen` в этой папке → откройте `AquaTime.xcodeproj`.
3. Вариант Б: Xcode → File → New → Project → iOS App (SwiftUI), имя AquaTime, удалите созданные ContentView.swift/AquaTimeApp.swift и перетащите 4 файла из папки `AquaTime/`.
4. Signing & Capabilities → выберите свою команду (Apple ID), подключите iPhone и нажмите ▶︎.

## Виджет, «Здоровье», кнопка в уведомлении
- Проще всего собрать через `xcodegen` — цели, App Group и HealthKit настроятся сами.
- Если меняете bundle id `com.example.aquatime`, замените и `group.com.example.aquatime` во всех файлах.
- Вручную в Xcode: File → New → Target → Widget Extension (имя AquaWidget, код из `AquaWidget/`);
  у обеих целей Signing & Capabilities → + App Groups `group.com.example.aquatime`;
  у приложения ещё + HealthKit, а в Info добавьте NSHealthShareUsageDescription, NSHealthUpdateUsageDescription
  и URL Type со схемой `aquatime`.
