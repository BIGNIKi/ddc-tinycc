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

## Самосборка tinycc (шаги 1–2)

Скрипт `build-branchA.sh` берёт один и тот же исходник tinycc (`tcc-mob.tar`)
и собирает из него компилятор дважды:

- **Шаг 1** — доверенный gcc собирает tinycc (`A1`). Проверяем, что gcc вообще
  собирает рабочий tinycc под musl.
- **Шаг 2** — `A1` собирает тот же tinycc (`A2`). Проверяем, что tinycc умеет
  собрать сам себя (`A1 → A2`).

Это доверенная ветка схемы DDC: `A → A1 → A2`. На шаге 3 появится проверяемая
ветка на независимом компиляторе (Alpine gcc): `B → B1 → B2`. На шаге 4 сравним
побайтово `A2` и `B2` — если совпали, исходник tinycc однозначно определяет бинарник
(база DDC работает).

**1. Достать чистый исходник tinycc** (кладём в `input/`, нужен интернет). Нужно сделать один раз —
если `input/tcc-mob.tar` уже есть, пропусти:

```sh
git clone --single-branch --branch mob https://github.com/TinyCC/tinycc.git tcc-upstream
git -C tcc-upstream archive --format=tar --prefix=tcc/ 9db1105c32afd3dcf0c28b8186f08e63c761b2b5 > input/tcc-mob.tar
```

**2. Запустить сборку в контейнере.**

Linux / macOS:

```sh
docker run --rm -v "$(pwd)":/work trusted-toolchain /bin/sh /work/src/build-branchA.sh
```

Windows (Git Bash), подставь свой путь к этой папке:

```sh
MSYS_NO_PATHCONV=1 docker run --rm -v "C:/path/to/ddc-tinycc":/work trusted-toolchain /bin/sh /work/src/build-branchA.sh
```

Готовые компиляторы появятся в папке `out/` (`tcc-A1`, `tcc-A2`). Ожидаемый хвост вывода:

```
tcc version 0.9.28rc (x86_64 Linux)
hi 42
```

(плюс контрольные суммы `A1` и `A2` — они разные, это нормально; сравнение между ветками будет на шаге 4).

## Файлы

- `src/utils/build-common.sh` — общая часть веток A и B (флаги сборки и функция сборки); подключается остальными скриптами.
- `src/build-branchA.sh` — ветка A: самосборка tinycc (шаги 1–2), запускается в контейнере `trusted-toolchain`.
- `src/build-branchB.sh` — ветка B: сборка tinycc независимым Alpine-gcc (шаг 3), запускается в контейнере `ddc-alpine`.
- `Dockerfile.branchB` — образ `ddc-alpine` (Alpine gcc + наши `/x86_64`) для ветки B.
- `input/` — входные данные для контейнера: `tcc-mob.tar` (исходник tinycc) и `hello.c` (тестовая программа).

## Статус

- [x] Шаг 1 — доверенный gcc собирает tinycc, tcc работает под musl.
- [x] Шаг 2 — самосборка: tcc собирает сам tinycc (`A1 → A2`).
- [ ] Шаг 3 — проверяемая ветка на независимом компиляторе (Alpine gcc): `B → B1 → B2`.
- [ ] Шаг 4 — двойная пересборка обеих веток и побайтовое сравнение `A2` и `B2`.
- [ ] Шаг 5 — всё в один скрипт-пайплайн.
