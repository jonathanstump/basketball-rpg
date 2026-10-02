extends QABoroughRun
## QA borough run: The Bronx (spec §16 M9a).


func run() -> bool:
	await frames(3)
	return await run_borough("bronx", ["bx_mott_haven", "bx_west_farms", "bx_highbridge"], ["bx_crab", "bx_silverback", "bx_boom"], "bx_boom")
