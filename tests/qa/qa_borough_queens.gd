extends QABoroughRun
## QA borough run: Queens (spec §16 M9b).


func run() -> bool:
	await frames(3)
	return await run_borough("queens", ["qn_roosevelt", "qn_astoria", "qn_flushing"], ["qn_express", "qn_sauce", "qn_atlas"], "qn_atlas")
