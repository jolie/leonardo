include "hooks_types.iol"

service PreResponseHook {
Interfaces: PreResponseHookIface
main {
	run(mesg)(mesg) {
		nullProcess
	}
}
}
