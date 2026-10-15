// Engine boundary stubs only. These tests execute the real wardrobe dispatcher.
static uint32_t fixtureModel=0x1234, fixtureRequested;
static bool fixtureLoaded=true,fixtureValid=true;
static int32_t fixtureDrawable[15]={0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1};
static int32_t fixtureTexture[15];
void w2c_game_f58625(w2c_game *g,u32 player,u32 model){(void)g;assert(player==0 && model==fixtureRequested && pg_wardrobe_preloaded_swap());fixtureModel=model;}
void w2c_game_f60322(w2c_game *g,u32 model){(void)g;fixtureRequested=model;}
u32 w2c_game_f60324(w2c_game *g,u32 model){(void)g;assert(model==fixtureRequested);return fixtureLoaded;}
void w2c_game_f60327(w2c_game *g,u32 model){(void)g;assert(model==fixtureRequested);}
u32 w2c_game_f60347(w2c_game *g,u32 model){(void)g;return model!=0;}
u32 w2c_game_f60348(w2c_game *g,u32 model){(void)g;return model!=0;}
u32 w2c_game_f50040(w2c_game *g,u32 ped){(void)g;assert(ped==101);return fixtureModel;}
u32 w2c_game_f57381(w2c_game *g,u32 p,u32 slot){(void)g;assert(p==101 && slot<12);return (u32)fixtureDrawable[slot];}
u32 w2c_game_f57382(w2c_game *g,u32 p,u32 slot){(void)g;assert(p==101 && slot<3);return 2;}
u32 w2c_game_f57383(w2c_game *g,u32 p,u32 slot){(void)g;assert(p==101 && slot<12);return 3;}
u32 w2c_game_f57384(w2c_game *g,u32 p,u32 slot){(void)g;assert(p==101 && slot<12);return (u32)fixtureTexture[slot];}
u32 w2c_game_f57385(w2c_game *g,u32 p,u32 slot,u32 draw){(void)g;assert(p==101 && slot<12 && draw<3);return 2;}
u32 w2c_game_f57386(w2c_game *g,u32 p,u32 slot,u32 draw){(void)g;assert(p==101 && slot<3 && draw<2);return 2;}
u32 w2c_game_f57391(w2c_game *g,u32 p,u32 slot,u32 draw,u32 texture){(void)g;assert(p==101 && slot<12 && draw<3 && texture<2);return fixtureValid;}
void w2c_game_f57392(w2c_game *g,u32 p,u32 slot,u32 draw,u32 texture,u32 palette){(void)g;assert(p==101 && slot<12 && draw<3 && texture<2 && palette==0);fixtureDrawable[slot]=draw;fixtureTexture[slot]=texture;}
void w2c_game_f57393(w2c_game *g,u32 p,u32 unused){(void)g;assert(p==101 && unused==0);}
void w2c_game_f57394(w2c_game *g,u32 p){(void)g;assert(p==101);}
void w2c_game_f57395(w2c_game *g,u32 p){(void)g;assert(p==101);}
u32 w2c_game_f57435(w2c_game *g,u32 p,u32 prop){(void)g;assert(p==101 && prop<3);return (u32)fixtureDrawable[prop+12];}
void w2c_game_f57436(w2c_game *g,u32 p,u32 prop,u32 draw,u32 texture,u32 attach){(void)g;assert(p==101 && prop<3 && draw<2 && texture<2 && attach==1);fixtureDrawable[prop+12]=draw;fixtureTexture[prop+12]=texture;}
u32 w2c_game_f57438(w2c_game *g,u32 p,u32 prop){(void)g;assert(p==101 && prop<3);return (u32)fixtureTexture[prop+12];}
void w2c_game_f57439(w2c_game *g,u32 p,u32 prop){(void)g;assert(p==101 && prop<3);fixtureDrawable[prop+12]=-1;fixtureTexture[prop+12]=0;}
void w2c_game_f57440(w2c_game *g,u32 p){(void)g;assert(p==101);for(int i=12;i<15;i++)fixtureDrawable[i]=-1;}
