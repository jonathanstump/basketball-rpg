class_name InputSource
extends RefCounted
## Fills an actor's ActorInput once per simulation frame. Subclasses: human
## input, scripted input (tests/QA), and AI brains.


func fill(_input: ActorInput, _actor: SimActor, _world: SimWorld) -> void:
	pass
