# Resource simulation

Open **Explore → Simulation** or use **⌘K** and choose **Simulation**. The resource model runs locally in Manual and AI Assisted modes. It starts with the quantities you enter and keeps the calculations in a hypothetical run.

1. In **Setup**, enter a run name, quantity unit, starting stock, capacity, and supply and demand per step. Environmental pressure deducts a fixed quantity from replenishment. Optional seeded variation adds or subtracts within the bound you set.
2. Choose an hour, year, century, or custom horizon. A year or century uses the number of hours you enter for your world. Choose a step size that divides the horizon exactly, within 10,000 steps.
3. Use **Run scenario** for the full horizon or **Run first step** to pause at the first boundary. **Change the next step** lets you schedule new assumptions or a signed delivery or loss. Then step once or finish.
4. Open a row in **Trace** to inspect the opening reserve, effective stock adjustment, authored supply, environmental deduction, seeded variation, served and unmet demand, and discarded surplus. Replenishment is clamped to zero after pressure and variation. Supply can meet demand in the same interval, and closing inventory is capped at storage capacity.
5. Use **Save run** to keep the exact input and trace in the current world. **Saved runs** reopens either a finished or a paused snapshot. Stepping forward or scheduling a change from a saved snapshot produces an unsaved continuation, leaving the original available. **Replay trace** recalculates the saved prefix and reports whether every row matches.
6. **Archive** hides a saved run. The Undo toast restores it. **Show archived runs** gives access to archived traces and their Restore action. Portable worlds and JSON include archived and active snapshots. Imported worlds receive new run IDs and preserve the calculated trace.

The first model uses one authored reserve and a fixed interval. Its outputs describe the consequences of those assumptions. Simulation results stay outside lore, canon, and the assistant's context. Work to apply selected effects through proposals or display them on other tools has its own expansion requirements.
