# ddc-tinycc

Пайплайн **Diverse Double-Compiling (DDC)** для проверки компилятора tinycc на наличие атаки
Томпсона (Trusting Trust). DDC должен находить атаку, которая сидит в бинарнике компилятора,
но отсутствует в его исходном коде.

Этот репозиторий содержит сам **метод** (скрипты).

Сейчас строим **чистую базу**: проверяем, что DDC проходит на **оригинальном**
(не заражённом) tinycc — то есть что метод и побайтовая воспроизводимость вообще работают.
Заражённый компилятор (`evil-tinycc`) — это следующий этап: когда база заработает, им
покажем, что DDC ловит атаку.

Компиляторы живут в отдельных проектах:

- доверенный компилятор — собирали ветку `trusted-toolchain-docker` (gcc 13.3.0, собран с нуля через
  live-bootstrap, под **musl**). Ссылка: https://github.com/ylab-nsu/trusted-toolchain-docker/tree/trusted-toolchain-docker;
- проверяемый компилятор (сейчас) — **чистый оригинальный tinycc** (0.9.28rc), ветка `mob`, коммит
  `9db1105c32afd3dcf0c28b8186f08e63c761b2b5`.
  Ссылка: https://github.com/TinyCC/tinycc/commit/9db1105c32afd3dcf0c28b8186f08e63c761b2b5;
- проверяемый компилятор (зараженный) - сейчас в разработке.

## Зафиксированные версии

| Что | Версия |
|-----|--------|
| tinycc (чистый исходник) | ветка `mob` официального TinyCC, коммит `9db1105c32afd3dcf0c28b8186f08e63c761b2b5` (`0.9.28rc`) |
| доверенный gcc | образ Docker `trusted-toolchain` (gcc 13.3.0, x86_64-linux-musl) |

**Почему свежий tinycc, а не 0.9.27:** релиз 0.9.27 не умеет компилировать под musl
(не знает `__builtin_va_list`, который используют musl-заголовки). В ветке `mob` эта
поддержка уже есть. Доверенный gcc собран под musl, поэтому берём musl-совместимый tinycc.

## Предпосылки

- Docker Desktop (запущен).
- Собранный образ `trusted-toolchain` (из проекта `trusted-toolchain-docker`).

## Шаг 1 — собрать tinycc доверенным gcc и проверить под musl

Проверяет, что доверенный gcc собирает tinycc и что получившийся tcc работает под musl
(компилирует и запускает программу).

**1. Достать чистый исходник tinycc** (в текущую папку, нужен интернет):

```sh
git clone --single-branch --branch mob https://github.com/TinyCC/tinycc.git tcc-upstream
git -C tcc-upstream archive --format=tar --prefix=tcc/ 9db1105c32afd3dcf0c28b8186f08e63c761b2b5 > tcc-mob.tar
```

**2. Собрать и проверить в контейнере.**

Linux / macOS:

```sh
docker run --rm -v "$(pwd)":/work trusted-toolchain /bin/sh /work/build-test.sh
```

Windows (Git Bash), подставь свой путь к этой папке:

```sh
MSYS_NO_PATHCONV=1 docker run --rm -v "C:/path/to/ddc-tinycc":/work trusted-toolchain /bin/sh /work/build-test.sh
```

Ожидаемый результат в конце:

```
tcc version 0.9.28rc (x86_64 Linux)
hi 42
```

## Файлы

- `build-test.sh` — сборка tinycc доверенным gcc + проверка (запускается внутри контейнера).
- `hello.c` — тестовая программа.

## Статус

- [x] Шаг 1 — доверенный gcc собирает tinycc, tcc работает под musl.
- [ ] Шаг 2 — самосборка: tcc собирает сам tinycc (второй шаг DDC).
- [ ] Шаг 3 — второй доверенный компилятор (скачанный musl-gcc) для «разнообразия».
- [ ] Шаг 4 — двойная пересборка обеих веток и побайтовое сравнение.
- [ ] Шаг 5 — всё в один скрипт-пайплайн.
