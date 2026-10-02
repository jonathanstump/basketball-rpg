extends QABoroughRun
## QA borough run: Staten Island (spec §16 M9c).


func run() -> bool:
	await frames(3)
	return await run_borough("staten_island", ["si_st_george", "si_narrows", "si_heap"], ["si_ferryman", "si_general", "si_heap"], "si_heap")
