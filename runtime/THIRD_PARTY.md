# Third-party runtime and fonts

The ARM LuaJIT and FBInk executables were obtained from the public KOReader v2026.07.1 `kindlepw2` release. KOReader is not required to run SoundRing.

- LuaJIT 2.1, `luajit`: MIT, see `LuaJIT-COPYING`; source https://github.com/LuaJIT/LuaJIT; SHA-256 `b830a60c2d0b0e64de37f20d18595990d5e408f945d2af4c0ea3181a13ed7f1c`.
- FBInk 1.25.0, `fbink`: GPLv3 or later, see `FBInk-LICENSE`; source https://github.com/NiLuJe/FBInk; binary bundle https://github.com/koreader/koreader/releases/tag/v2026.07.1; SHA-256 `f6f70557d351657f7e4900b61dfc89d7068e72a9fc0710e6a8ff6e8223bfbe56`. For the corresponding source release and build toolchain see the FBInk and https://github.com/koreader/koxtoolchain projects.
- FreeType `libfreetype.so.6`: see `FreeType-FTL.txt`, source https://github.com/freetype/freetype; SHA-256 `5b2d001dbb15c69b93a1ec776954f15c7b89a3d572ca3f3235fc0aeb7ed30ec2`. This software uses the FreeType Project (https://freetype.org). All rights reserved.
- zlib `libz.so.1`: see `zlib-LICENSE.txt`, source https://github.com/madler/zlib; SHA-256 `5f34b46fdf855d13e2e7183dae75cf83cbe76f830a41b1707fcf9365d5301e77`.
- `coverconv` uses the third-party notices in `licenses/` and source in `tools/coverconv/`.
- Fonts: MiSans (application archive only), Kumbh Sans, Source Han Sans and Noto Sans. Their individual license notices are in `app/assets/fonts/` in the package and `assets/fonts/` in the repository. The application uses MiSans.
