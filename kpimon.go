package main

// import ("example.com/kpimon/control")

import (
	"./kpimon/control"
)

func main() {
	c := control.NewControl()
	c.Run()
}
