# import os
import strutils, tables
from clymene/cli import confirm

proc runNewCmd*(args: Table[system.string, system.any]): string =
    for project in @(args["<project>"]): 
        echo "Creating a new Denim project for $#" % project

    # let confirmation = confirm("Project already exist? Do you want to delete?")
    # echo confirmation
