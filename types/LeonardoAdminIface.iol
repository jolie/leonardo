type LeonardoBinding:void {
	.location:any
	.protocol?:string { ? }
}

type LeonardoConfiguration:void {
	.wwwDir?:string
	.PreResponseHook?:LeonardoBinding
	.PostResponseHook?:LeonardoBinding
	.redirection*:void {
		.name:string
		.binding:LeonardoBinding
	}
}

interface LeonardoAdminIface {
RequestResponse: config(LeonardoConfiguration)(void)
}
