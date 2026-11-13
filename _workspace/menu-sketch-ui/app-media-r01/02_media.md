# MENU09 앱 미디어 제작

기존 MENU09 검토 자료에서 신기 이미지 6개와 영상 포스터 22개를 바이트 그대로 복사했다. 실버 문양과 조약돌 요요 이미지는 기존 등록 파일을 사용한다. 소개 영상 22개는 같은 MP4에서 Godot 내장 재생 형식인 Ogg Theora로 변환했다. 대상 파일과 SHA256은 [앱 미디어 목록](app-media-manifest.json)에 기록했다.

| 자산 | 수량 | 앱 리소스 ID | 파일 크기 합계 |
| --- | ---: | --- | ---: |
| 신기 이미지 | 6 | `fa.ui.menu09.artifact.<short-id>` | 7,513,592바이트 |
| 영상 포스터 | 22 | `fa.ui.menu09.poster.<owner>.<clip>` | 20,877,452바이트 |
| Ogg Theora 영상 | 22 | `fa.ui.menu09.video.<owner>.<clip>` | 14,984,700바이트 |
| 기존 실버 문양 | 1 | `fa.rank.rank.silver` | 기존 파일 참조 |
| 기존 요요 이미지 | 1 | `fa.accessory.pebble.yoyo` | 기존 파일 참조 |

신규 파일 50개의 합은 약 41.4MiB다. 앱은 `ForestArenaResources`로 ID를 읽는다. 영상은 매니저가 찾은 경로를 Godot `VideoStreamTheora`로 연다. 영상 22개는 960×540, 초당 30프레임, 무음이다. 재생 시간은 원본과 각각 일치한다. 장비와 기술 설명 및 상태 글자는 원본 영상 프레임에 들어 있으며 그대로 함께 변환했다. Ogg 사본은 재생 부담을 줄이기 위해 원본의 60fps를 30fps로 줄였다. APK 실제 용량과 기기 재생은 앱 통합 검사에서 측정한다.

## 변환 도구

기존 Homebrew FFmpeg 9.0.1에는 Theora 디코더가 있지만 인코더가 빠져 있다. 별도 동영상 플러그인을 추가하면 앱의 내보내기와 기기별 호환성 검사가 늘어난다. Godot에서 이미 지원하는 Ogg Theora를 만들기 위해 Xiph.Org의 1.2.0 참조 인코더를 빌드 도구로 사용했다. [Godot 동영상 재생 문서](https://docs.godotengine.org/en/4.3/tutorials/animation/playing_videos.html) · [Xiph.Org 공식 배포](https://www.xiph.org/downloads/)

Xiph 배포 소스 `libtheora-1.2.0.tar.gz`를 다운로드하고 공개된 SHA256 `279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e`와 대조했다. 소스의 README, `configure.ac`, 예제 빌드 규칙과 `COPYING`을 확인한 뒤 임시 폴더에서 빌드했다. 라이브러리는 3절 BSD 라이선스다. 인코더, 라이브러리와 소스 코드는 게임이나 저장소에 배포하지 않는다. FFmpeg로 YUV4MPEG2 프레임을 공급하고 Xiph의 `examples/encoder_example`로 인코딩했다. 기존 libogg와 libvorbis를 사용해 시스템 설치 없이 시험했다. [Xiph 1.2 릴리스 및 라이선스](https://xiph.org/press/2025/theora-release-1.2/)

이 Mac의 재현 절차는 아래와 같다. 첫 두 명령은 SHA256이 일치하는 공식 소스의 압축을 푼 임시 폴더에서 실행한다. 세 번째 명령은 Forest Arena 작업 폴더에서 실행한다.

```sh
./configure --disable-shared --enable-static --disable-asm --disable-doc --disable-spec --with-ogg=/opt/homebrew --with-vorbis=/opt/homebrew
make -j 8
python3 _workspace/menu-sketch-ui/app-media-r01/build_app_media.py --encoder /absolute/path/libtheora-1.2.0/examples/encoder_example
```

도구는 원본 해시와 대상 슬롯을 먼저 확인한다. 인코딩된 22개가 모두 규격과 전체 디코드 검사를 통과하면 앱 자산, 등록 목록과 변환 기록을 쓴다. 이 미디어 작업을 되돌릴 때는 신규 50개 등록 행과 `forest_arena/assets/ui/menu09-media/`의 생성 파일을 한 변경으로 되돌린다. 실버와 요요의 기존 행은 그 범위에서 빠진다.

## 검사 결과

- 복사한 PNG 28개 모두 원본 SHA256과 동일하다. 실버 기존 파일도 검토 자료의 해시와 동일하다.
- FFprobe에서 영상 22개 모두 Theora 단일 스트림, 960×540, 30fps와 원본 대비 재생 시간 차이 0초를 확인했다. FFmpeg 전체 디코드 22개를 통과했다.
- 실제 Ogg 디코딩 화면에서 자현 특수·나비 3타 연계·철갑옷·조약돌 요요를 열어 확인했다. 기술명, 현재 상태, 무게·지상 속도 글자와 요요의 실 연결이 960×540 화면에서 읽혔다.
- `python3 tools/forest_arena/verify_godot_resources.py --project-root .`를 통과했다. 카탈로그 571개와 품질 변형 대상 25개를 확인했다.
- Godot 4.7.1의 격리 프로젝트에서 실제 앱 리소스 매니저와 카탈로그를 사용했다. 신규·재사용 이미지 30개를 논리 ID로 불러왔다. Ogg Theora 22개가 모두 재생을 시작하고 960×540 텍스처와 진행 시간을 반환했다. 철갑옷 영상은 끝까지 재생해 종료 신호를 확인했다.
