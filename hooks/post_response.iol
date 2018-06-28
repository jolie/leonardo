include "hooks_types.iol"

service PostResponseHook {
Interfaces: PostResponseHookIface
main {
	run(mesg)() {
		nullProcess
	}
}
}
