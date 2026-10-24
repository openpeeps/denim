# Shared CLI helpers for the denim command line.
# Same usage styling as striptease: bold-white section labels,
# dimmed grey comments, NO_COLOR aware. Stdlib only.

import std/[os, strutils]

const versionStr* = "0.2.1"

const
  ansiReset = "\e[0m"
  ansiBoldWhite = "\e[1;37m"
  ansiGrey = "\e[90m"
  ansiRed = "\e[31m"

proc useColor*(): bool =
  getEnv("NO_COLOR") == "" and getEnv("TERM") != "dumb"

proc paint*(s, code: string): string =
  if useColor():
    code & s & ansiReset
  else:
    s

proc label*(s: string): string =
  paint(s, ansiBoldWhite)

proc grey*(s: string): string =
  paint(s, ansiGrey)

proc errPrefix*(): string =
  paint("error:", ansiRed)

proc display*(msg: string) =
  echo msg

proc displayInfo*(msg: string) =
  echo "Info: " & msg

proc displaySuccess*(msg: string) =
  echo "Success: " & msg

proc displayError*(msg: string) =
  echo errPrefix() & " " & msg

proc promptConfirm*(question: string): bool =
  stdout.write question & " "
  try:
    return stdin.readLine().strip().toLowerAscii() in ["y", "yes"]
  except EOFError:
    return false
  except CatchableError:
    return false
