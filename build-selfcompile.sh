#!/bin/sh
# Сборка tinycc доверенным gcc (A1) и сборка этим A1 своих исходников (A2).
#
#   ШАГ 1: A1 = доверенный gcc собирает tinycc
#          (проверяем, что gcc собирает рабочий tinycc под musl)
#   ШАГ 2: A2 = A1 (наш доверенный tcc) собирает свои исходники
#          (проверяем, что tinycc умеет собрать сам себя: A1 -> A2)
#
# Запускается ВНУТРИ контейнера trusted-toolchain.
# Ожидаем в /work: tcc-mob.tar (исходник), hello.c (тест).
# Готовые бинарники кладём в /work/out (A1, A2) — чтобы можно было посмотреть с хоста.

# всё происходит внутри контейнера, но на монтированной папке work.
# То есть файлы будут на хосте.
SRC=/work/tcc-mob.tar
OUT=/work/out
mkdir -p "$OUT"

# Общие флаги configure под musl-окружение образа. В функции build они передаются
# в ./configure (компилятор --cc подставляется отдельно: на шаге 1 это gcc, на шаге 2 — A1).
# файл configure - из репозитория tinycc (https://github.com/TinyCC/tinycc)
# через configure можно настроить: под какую ОС собирать, под какую архитектуру процессора, какую libc (glibc, musl) использовать и т.д.
# В makefile лезть не нужно, достаточно настроить configure.
# --sysincludepaths=/x86_64/usr/include: где искать системные заголовки (stdio.h и т.д.)
# --libpaths=/x86_64/usr/lib:/x86_64/lib: где искать библиотеки (libc, libtcc1.a). То есть реализации заголовков.
# --crtprefix=/x86_64/usr/lib: где взять стартовые файлы программы (crt1.o, crti.o, crtn.o). То есть это точка входа _start, которая запускается ещё до main; а также логика, которая выполняется после main.
# 	В будущем, эти файлы будут "приклеиваться" к программам, которые tinycc собирает.
# --elfinterp=/lib/ld-musl-x86_64.so.1: какой динамический загрузчик будут использовать собранные программы при запуске (musl-загрузчик)
# Отключаем ненужное (конфликтует с musl, для нас не требуется):
# --config-bcheck=no: без проверки границ массивов;
# --config-backtrace=no: без трассировки стека.
CONF="--sysincludepaths=/x86_64/usr/include \
  --libpaths=/x86_64/usr/lib:/x86_64/lib \
  --crtprefix=/x86_64/usr/lib \
  --elfinterp=/lib/ld-musl-x86_64.so.1 \
  --config-bcheck=no --config-backtrace=no"

# build <компилятор-для-сборки> <куда-положить-готовый-tcc>
build() {
  # папка tmp сразу есть в контейнере
  # rm -rf tcc — на случай, если build вызывается повторно (шаг 2 после шага 1):
  #              чистим распаковку от прошлого захода, чтобы собирать с нуля
  # (tar xf "$SRC") распаковываем архив с исходниками tinycc. В tmp появится папка tcc
  cd /tmp && rm -rf tcc && tar xf "$SRC" && cd tcc

  # (find . -type f) - находим все файлы, рекурсивно в подпапках тоже
  # (-exec ... {} +) - для всех файлов выполнить команду
  # (sed -i 's/\r$//') - сама команда для каждого файла (убирает виндовые концы строк)
  # 2>/dev/null (ошибки не выводить)
  find . -type f -exec sed -i 's/\r$//' {} + 2>/dev/null

  # --cc="$1": каким компилятором собирать (шаг 1 — gcc, шаг 2 — A1)
  sh ./configure --cc="$1" $CONF

  make tcc                                 # сам компилятор
  sed -i 's/\btcov.o\b//g' lib/Makefile    # tcov конфликтует с musl, он не нужен
  make 2>/dev/null                         # собирает libtcc1.a
  [ -f libtcc1.a ] || { echo "libtcc1.a не собралась"; exit 1; }
  cp -f libtcc1.a /x86_64/usr/lib/         # tcc ищет её в библиотечном пути
  cp -f tcc "$2"                           # сохраняем готовый компилятор ($2 внутри /work/out)
}

echo "=== ШАГ 1: доверенный gcc собирает tinycc (A1) ==="
build gcc "$OUT/tcc-A1"

echo "=== ШАГ 2: A1 собирает тот же tinycc — самосборка (A2) ==="
build "$OUT/tcc-A1" "$OUT/tcc-A2"

echo "=== проверка, что A2 рабочий ==="
"$OUT/tcc-A2" -v
"$OUT/tcc-A2" /work/hello.c -o /tmp/hello && /tmp/hello

echo "=== контрольные суммы ==="
sha256sum "$OUT/tcc-A1" "$OUT/tcc-A2"
