"""Reuse read-only pose inspection, directing all outputs to the Nabi batch."""
import inspect_style_proofs as inspector

if __name__ == '__main__':
    inspector.BATCH = inspector.WORK / '07_nabi-style-locked'
    inspector.main(allow_incomplete=True)
