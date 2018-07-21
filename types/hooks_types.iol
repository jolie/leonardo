type LeonardoConfig:void {
	.wwwDir:string
}

type DecoratedResponse:void {
	.config:LeonardoConfig
	.request:void {
		.path:string
	}
	.content?:string
}
