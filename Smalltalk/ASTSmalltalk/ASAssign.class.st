"
I represent an assignment expression. This stores the value of an expression in a variable (local, inherited local, instance, class, shared).
"
Class {
	#name : #ASAssign,
	#superclass : #ASExpression,
	#instVars : [
		'expression',
		'variable'
	],
	#category : #'ASTSmalltalk-AST'
}

{ #category : #'instance creation' }
ASAssign class >> variable: v expression: e [
^ self new variable: v expression: e
]

{ #category : #comparing }
ASAssign >> = other [

	^ self class = other class and: [ self variable = other variable and: [ self expression = other expression ] ]
]

{ #category : #comparing }
ASAssign >> expression [
	^ expression
]

{ #category : #printing }
ASAssign >> printOn: s [

	s << self className << ' variable: '.
	variable printOn: s.
	s << ' expression: ('.
	expression printOn: s.
	s << ')'
]

{ #category : #comparing }
ASAssign >> variable [
	^ variable
]

{ #category : #accessing }
ASAssign >> variable: v expression: e [

	variable := v.
	expression := e
]