/*
   Copyright 2008-2022 Fabrizio Montesi <famontesi@gmail.com>

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

	inputPort HTTPInput {
		location: params.location
		protocol: http {
			keepAlive = true // Keep connections open
			debug = is_defined( params.httpConfig.debug ) && params.httpConfig.debug
			debug.showContent = is_defined( params.httpConfig.debug.showContent ) && params.httpConfig.debug.showContent
			format -> httpParams.format
			contentType -> httpParams.contentType
			statusCode -> statusCode
			redirect -> redirect
			cacheControl.maxAge -> httpParams.cacheControl.maxAge
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

	embed Console as console
	embed StringUtils as stringUtils
	embed File as file
	embed Runtime as runtime
	embed WebFiles as webFiles

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
						println@console( "File not found: " + computeResponse.FileNotFound )()
						statusCode = 404,
					MovedPermanently =>
						redirect = computeResponse.MovedPermanently
						statusCode = 301
				)

				get@webFiles( {
					target = request.operation
					wwwDir = params.wwwDir
					defaultPage = params.defaultPage
				} )( getResult )
				httpParams -> getResult.httpParams
				
				runPostResponseHook = true

				install( PreResponseFault =>
					response = computeResponse.PreResponseFault.response
					statusCode = computeResponse.PreResponseFault.statusCode
					runPostResponseHook = false
				)
				with( decoratedResponse ) {
					.config.wwwDir = params.wwwDir;
					.request.path = getResult.path;
					if( getResult.format == "html" ) {
						.content -> getResult.content
					}
				}
				run@preResponseHook( decoratedResponse )( newResponse )
				if( !(newResponse instanceof void) ) {
					response -> newResponse
				} else {
					response -> getResult.content
				}
			}
		} ] {
			if( runPostResponseHook ) {
				run@postResponseHook( decoratedResponse )()
			}
		}
	}
}

type GetRequest {
	target:string
	wwwDir:string
	defaultPage?:string ///< default: index.html
}

type GetResponse {
	content:string | raw
	path:string

	httpParams {
		format:string
		contentType:string
		cacheControl? {
			maxAge:int
		}
	}
}

interface WebFilesInterface {
RequestResponse:
	get( GetRequest )( GetResponse ) throws FileNotFound(string) MovedPermanently(string)
}

service WebFiles {
	execution: concurrent

	inputPort Input {
		location: "local"
		interfaces: WebFilesInterface
	}

	embed StringUtils as stringUtils
	embed File as file
	embed Console as console

	init {
		getFileSeparator@file()( fs )
		getRealServiceDirectory@file()( dir )
		setMimeTypeFile@file( dir + fs + "internal" + fs + "mime.types" )()
		undef( fs )
		undef( dir )
		maliciousSubstrings[0] = ".."
		maliciousSubstrings[1] = ".svn"
		maliciousSubstrings[2] = ".git"

		install(
			FileNotFound => nullProcess,
			MovedPermanently => nullProcess
		)
	}

	define setCacheHeaders {
		if( s.result[0] == "image"
			|| endsWith@stringUtils( f.filename { suffix = ".js" } )
			|| endsWith@stringUtils( f.filename { suffix = ".css" } )
			|| endsWith@stringUtils( f.filename { suffix = ".woff" } ) ) {
			response.httpParams.cacheControl.maxAge = 60 * 60 * 2 // 2 hours
		}
	}

	define checkForMaliciousPath {
		for( maliciousSubstring in maliciousSubstrings ) {
			if( contains@stringUtils( s.result[0] { substring = maliciousSubstring } ) ) {
				throw( FileNotFound )
			}
		}
	}

	main {
		get( request )( response ) {
			getFileSeparator@file()( fs )
			if( !endsWith@stringUtils( request.wwwDir { suffix = fs } ) ) {
				request.wwwDir += fs
			}

			split@stringUtils( request.target { regex = "\\?" } )( s )

			// DefaultPage
			if( s.result[0] == "" || endsWith@stringUtils( s.result[0] { suffix = "/" } ) ) {
				s.result[0] +=
					if( is_defined( request.defaultPage ) )
						request.defaultPage
					else "index.html"
			}

			checkForMaliciousPath

			userPath = s.result[0]
			response.path = request.wwwDir + userPath

			f.filename = response.path

			isDirectory@file( f.filename )( isDirectory )
			if( isDirectory ) {
				redirect = userPath + "/"
				throw( MovedPermanently, redirect )
			}

			getMimeType@file( f.filename )( response.httpParams.contentType )
			split@stringUtils( response.httpParams.contentType { regex = "/" } )( s )
			if( s.result[0] == "text" ) {
				f.format = "text"
				response.httpParams.format = "html"
			} else {
				f.format = "binary"
				response.httpParams.format = "binary"
			}

			setCacheHeaders

			readFile@file( f )( response.content )
		}
	}
}