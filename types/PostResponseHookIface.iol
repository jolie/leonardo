include "hooks_types.iol"

interface PostResponseHookIface {
RequestResponse: run(DecoratedResponse)(void)
}
