#!/bin/sh
# Проверяемая ветка B схемы DDC. Тот же исходник tinycc, но собирает
# его НЕЗАВИСИМЫЙ компилятор — gcc из Alpine (другая версия, другая сборка).
#
#   ШАГ 3.1: B1 = Alpine-gcc собирает tinycc
#   ШАГ 3.2: B2 = B1 собирает тот же tinycc (самосборка ветки B)
#
# Окружение (/x86_64 — musl-заголовки, библиотеки, crt) то же, что у ветки A:
# оно вшито в образ ddc-alpine. Разнится только сам компилятор на шаге 3.1.
#
# Запускается ВНУТРИ контейнера ddc-alpine (см. Dockerfile.branchB).
# Ожидаем в /work/input (папку /work монтируем): tcc-mob.tar (исходник tinycc), hello.c (тестовая программа).
# Готовые бинарники кладём в /work/out (B1, B2).

# Подключаем общую часть: SRC (исходники tinycc), OUT (папка, куда упадут собранные компиляторы), флаги CONF (вся конфигурация сборки компиляторов) и функцию build().
# (тот же файл подключает и ветка A — build-branchA.sh)
. /work/src/utils/build-common.sh

echo "=== ШАГ 3.1: Alpine-gcc собирает tinycc (B1) ==="
build gcc "$OUT/tcc-B1"

echo "=== ШАГ 3.2: B1 собирает тот же tinycc — самосборка (B2) ==="
build "$OUT/tcc-B1" "$OUT/tcc-B2"

echo "=== проверка, что B2 рабочий ==="
"$OUT/tcc-B2" -v
"$OUT/tcc-B2" /work/input/hello.c -o /tmp/hello && /tmp/hello

echo "=== контрольные суммы ветки B ==="
sha256sum "$OUT/tcc-B1" "$OUT/tcc-B2"

# Если ветка A уже собрана (есть tcc-A2) — сразу прикинем, совпали ли A2 и B2.
# Это предварительный взгляд; формальное сравнение — шаг 4.
if [ -f "$OUT/tcc-A2" ]; then
  echo "=== предварительное сравнение A2 и B2 ==="
  sha256sum "$OUT/tcc-A2" "$OUT/tcc-B2"
  if cmp -s "$OUT/tcc-A2" "$OUT/tcc-B2"; then
    echo "A2 и B2 СОВПАЛИ побайтово"
  else
    echo "A2 и B2 РАЗЛИЧАЮТСЯ (разберёмся на шаге 4)"
  fi
fi
