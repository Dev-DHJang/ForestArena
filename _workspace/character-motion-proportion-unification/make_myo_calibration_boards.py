"""Contact sheets of raw pose-coordinate guides; never alter source drawings."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"

def main():
    inspected=json.loads((BATCH/"04_review/inspection/report.json").read_text())
    calibrated=json.loads((BATCH/"05_remaining/landmarks-r01.json").read_text())["states"]
    remaining=[r for r in inspected if r["state"] not in calibrated and r["state"] not in ("idle","run","attack_air_heavy")]
    out=BATCH/"04_review/inspection/calibration-boards"
    out.mkdir(exist_ok=True)
    for start in range(0,len(remaining),6):
        board=Image.new("RGB",(1020,760),"#344154")
        draw=ImageDraw.Draw(board)
        for offset,row in enumerate(remaining[start:start+6]):
            state=row["state"]
            index=row.get("calibration_index",0)
            pose=Image.open(BATCH/f"04_review/inspection/{state}-pose{index+1:02}.png")
            scale=min(285/pose.width,320/pose.height)
            resized=pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.LANCZOS)
            xx=(offset%3)*340+40
            yy=(offset//3)*380+35
            board.paste(resized,(xx,yy),resized)
            draw.text((xx-35,yy-25),f"{state} / frame {index+1}",fill="white")
            for y in range(0,pose.height,10):
                y_line=yy+round(y*scale)
                draw.line((xx,y_line,xx+resized.width,y_line),fill="#61718b")
                draw.text((xx-32,y_line-4),str(y),fill="white")
            draw.text((xx-35,yy+330),f"source {pose.width} x {pose.height}",fill="white")
        path=out/f"page-{start//6+1:02}.png"
        board.save(path)
        print(path.name,[r["state"] for r in remaining[start:start+6]])

if __name__=="__main__":
    main()
