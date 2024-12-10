"
I create a context on the current stack.

There may be values above where the context goes, which will be saved.
"
Class {
	#name : 'ASCCreateContext',
	#superclass : 'ASCNonStackReferencingOperations',
	#instVars : [
		'context'
	],
	#category : 'Zag-Core-CodeGen',
	#package : 'Zag-Core',
	#tag : 'CodeGen'
}

{ #category : 'callgraph' }
ASCCreateContext >> dotStringOn: aStream [

	aStream << 'createContext'
]

{ #category : 'stack' }
ASCCreateContext >> resultStack: anASStack basicBlock: aBasicBlock [

	context := anASStack context.
	stack := anASStack.
	^ anASStack
]