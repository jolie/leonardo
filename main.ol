/*
   Copyright 2008-2020 Fabrizio Montesi <famontesi@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

from console import Console
from file import File
from protocols.http import DefaultOperationHttpRequest
from runtime import Runtime
from string-utils import StringUtils
from types.Binding import Binding

from .hooks import PreResponseHookIface, PostResponseHookIface

type LeonardoBinding {
	location:any
	protocol?:string { ? }
}

/// Configuration parameters
type Params {
	location:string //< location on which the web server should be exposed.
	wwwDir?:string //< path to the directory containing the web files. Default: /var/lib/leonardo/www/
	defaultPage:string	//< default page to be served when clients ask for a directory. Default: "index.html"
	/// configuration parameters for the HTTP input port
	httpConfig? {
		/// default = false
		debug?:bool { 
			showContent?:bool //< default = false
		}
	}
	preResponseHook?:LeonardoBinding //< Binding to a custom PreResponseHook
	postResponseHook?:LeonardoBinding //< Binding to a custom PostResponseHook
	/// Redirections to sub-services
	redirection* {
		name:string //< name of the service
		binding:LeonardoBinding //< Binding to the target service
	}
}

interface HTTPInterface {
RequestResponse:
	default( DefaultOperationHttpRequest )( undefined )
}

service Leonardo( params:Params ) {
	execution: concurrent

	embed Console as console
	embed StringUtils as stringUtils
	embed File as file
	embed Runtime as runtime

	inputPort HTTPInput {
		location: params.location
		protocol: http {
			keepAlive = true // Keep connections open
			debug = is_defined( params.httpConfig.debug ) && params.httpConfig.debug
			debug.showContent = is_defined( params.httpConfig.debug.showContent ) && params.httpConfig.debug.showContent
			format -> format
			contentType -> mime
			statusCode -> statusCode
			redirect -> redirect
			cacheControl.maxAge -> cacheMaxAge

			default = "default"
		}
		interfaces: HTTPInterface
	}

	outputPort preResponseHook {
		interfaces: PreResponseHookIface
	}

	outputPort postResponseHook {
		interfaces: PostResponseHookIface
	}

	define setCacheHeaders {
		shouldCache = false
		if( s.result[0] == "image" ) {
			shouldCache = true
		} else {
			e = file.filename
			e.suffix = ".js"
			endsWith@stringUtils( e )( shouldCache )
			if( !shouldCache ) {
				e.suffix = ".css"
				endsWith@stringUtils( e )( shouldCache )
				if( !shouldCache ) {
						e.suffix = ".woff"
						endsWith@stringUtils( e )( shouldCache )
				}
			}
		}

		if( shouldCache ) {
			cacheMaxAge = 60 * 60 * 2 // 2 hours
		}
	}

	define checkForMaliciousPath {
		for( maliciousSubstring in maliciousSubstrings ) {
			contains@stringUtils( s.result[0] { substring = maliciousSubstring } )( b )
			if( b ) {
				throw( FileNotFound )
			}
		}
	}

	define loadHooks {
		if( is_defined( params.preResponseHook ) ) {
			preResponseHook << params.preResponseHook
		} else {
			loadEmbeddedService@runtime( {
				filepath = "internal/hooks/pre-response.ol"
				type = "Jolie"
			} )( preResponseHook.location )
		}

		if( is_defined( params.postResponseHook ) ) {
			postResponseHook << params.postResponseHook
		} else {
			loadEmbeddedService@runtime( {
				filepath = "internal/hooks/post-response.ol"
				type = "Jolie"
			} )( postResponseHook.location )
		}
	}

	init {
		maliciousSubstrings[0] = ".."
		maliciousSubstrings[1] = ".svn"
		maliciousSubstrings[2] = ".git"
	}

	define setRedirections {
		for( redirection in params.redirection ) {
			with( request ) {
				.name = "#" + redirection.name;
				.location = redirection.binding.location;
				if ( is_defined( redirection.binding.protocol ) ) {
					.protocol << redirection.binding.protocol
				}
			}
			setOutputPort@runtime( request )()
			undef( request )
			setRedirection@runtime( {
				inputPortName = "HTTPInput"
				outputPortName = "#" + redirection.name
				resourceName = redirection.name
			} )()
		}
	}

	init {
		if( !is_defined( params.wwwDir ) ) {
			params.wwwDir = "/var/lib/leonardo/www/"
		}

		setRedirections
		loadHooks

		toAbsolutePath@file( params.wwwDir )( params.wwwDir )
		getFileSeparator@file()( fs )
		params.wwwDir += fs

		getServiceParentPath@file()( dir )
		setMimeTypeFile@file( dir + fs + "internal" + fs + "mime.types" )()
		undef( dir )
		undef( fs )

		format = "html"
		println@console( "Leonardo started\n\tLocation: " + global.inputPorts.HTTPInput.location + "\n\tWeb directory: " + params.wwwDir )()
	}

	main {
		[ default( request )( response ) {
			runPostResponseHook = false
			scope( computeResponse ) {
				install(
					FileNotFound =>
						println@console( "File not found: " + file.filename )()
						statusCode = 404,
					MovedPermanently =>
						statusCode = 301
				)

				split@stringUtils( request.operation { regex = "\\?" } )( s )

				// <DefaultPage>
				if( s.result[0] == "" || endsWith@stringUtils( s.result[0] { suffix = "/" } ) ) {
					s.result[0] += params.defaultPage
				}
				// </DefaultPage>

				checkForMaliciousPath

				requestPath = s.result[0]

				file.filename = params.wwwDir + requestPath

				isDirectory@file( file.filename )( isDirectory )
				if( isDirectory ) {
					redirect = requestPath + "/"
					throw( MovedPermanently )
				}

				getMimeType@file( file.filename )( mime )
				split@stringUtils( mime { regex = "/" } )( s )
				if( s.result[0] == "text" ) {
					file.format = "text"
					format = "html"
				} else {
					file.format = format = "binary"
				}

				setCacheHeaders

				readFile@file( file )( response )

				runPostResponseHook = true

				install( PreResponseFault =>
					response = computeResponse.PreResponseFault.response
					statusCode = computeResponse.PreResponseFault.statusCode
					runPostResponseHook = false
				)
				with( decoratedResponse ) {
					.config.wwwDir = params.wwwDir;
					.request.path = requestPath;
					if( file.format == "text" ) {
						.content -> response
					}
				}
				run@preResponseHook( decoratedResponse )( newResponse )
				if( !(newResponse instanceof void) ) {
					response -> newResponse
				}
			}
		} ] {
			if( runPostResponseHook ) {
				run@postResponseHook( decoratedResponse )()
			}
		}
	}
}
