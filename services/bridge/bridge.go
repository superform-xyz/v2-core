package bridge

/*
- Registry stores all protocol contracts including the SuperBridge contract.
- Bridge service interacts with the registry contract to get the address of the SuperBridge contract.
- Bridge service listens for events from the SuperBridge contract.
*/

type Bridge struct {
}

func New() *Bridge {
	return &Bridge{}
}

func (b *Bridge) Start() {

}
