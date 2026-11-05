# MENU09 미디어 반영본

이미지7종(새 원화6·기존 실버1)과 소개 영상22종을 공급한다. 새 미디어의 사용자 검토 상태는 대기다. 기존284개 승인 화면은 보존하고30~33번 별도 Penpot 페이지에서 반영본을 제공한다.

[Penpot 미디어 검토 시작](https://design.penpot.app/?screen=viewer&file-id=d8ac01df-6646-81d2-8008-a3696fea940e&page-id=2e6ebb69-a5b6-8066-8008-e5b77df5280f&section=interactions&frame-id=2e6ebb69-a5b6-8066-8008-e5b8f45305b4&zoom=fit)

- [29슬롯·파일·해시 대응표](asset-map.json)
- [이미지7종 기록](02_image.md) / [6아이콘 미리보기](images/contact-sheet.png)
- [영상22종 기록](02_video.md) / [영상 명세](video/manifest.json) / [전체 포스터](video/all-video-posters.png)
- [Penpot 반영 명세](02_ui.md) / [독립 QA](03_qa_r01.md)
- [요청](00_request.md) / [제작 계약](01_contract.md) / [종료·통합 기록](04_closeout.md)

[미디어 검토 페이지](http://127.0.0.1:4471/)는 현재 컴퓨터에서 재생한다. 서버가 종료되었으면 이 폴더에서 `python3 serve_preview.py`를 실행한다.127.0.0.1에만 열며 외부에 공개하지 않는다. 전체 파일을 받은 다른 환경에서는 같은 폴더 구조로 검토 서버를 실행한다. MP4는 video/ 안에서 직접 열 수도 있다.

Penpot 현재 플러그인 SDK에는 동영상 shape가 없으므로 포스터 이미지와 기본 open-url 재생 버튼을 사용한다. 버튼은 검토 페이지의 해당 슬롯을 새 탭으로 연다. Penpot 안에서 실제 영상이 재생된 것으로 기록하지 않는다. 최종 게임의 영상 포맷·플레이어·품질 등급 및 Android 실기기 재생은 후속 구현 때 정한다. 이번 MP4는 무음 검토·전달용이며 Godot 런타임에 등록하지 않는다.
