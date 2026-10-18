"""유란 원본의 16포즈 분리·잘림 검사와 좌표 안내판."""
import inspect_style_proofs as inspector
inspector.BATCH = inspector.WORK / '08_yu_ran-style-locked'
if __name__ == '__main__':
    inspector.main(allow_incomplete=True)
