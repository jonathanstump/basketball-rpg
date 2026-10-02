extends QABoroughRun
## QA borough run: Uptown (spec §16 M9d).


func run() -> bool:
	await frames(3)
	return await run_borough("uptown", ["up_harlem", "up_heights", "up_mecca"], ["up_hook", "up_coop", "up_highrise"], "up_highrise")
