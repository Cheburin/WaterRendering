#include "main.h"

#include "DXUTgui.h"
#include "SDKmisc.h"

extern GraphicResources * G;

extern SwapChainGraphicResources * SCG;

extern SceneState scene_state;

extern BlurHandling blur_handling;

extern CDXUTTextHelper*                    g_pTxtHelper;

ID3D11ShaderResourceView* null[] = { nullptr, nullptr, nullptr, nullptr, nullptr, nullptr };

inline void set_scene_constant_buffer(ID3D11DeviceContext* context){
	G->scene_constant_buffer->SetData(context, scene_state);
};

inline void set_blur_constant_buffer(ID3D11DeviceContext* context){
	//G->blur_constant_buffer->SetData(context, blur_handling);
};

void RenderText()
{
	g_pTxtHelper->Begin();
	g_pTxtHelper->SetInsertionPos(2, 0);
	g_pTxtHelper->SetForegroundColor(D3DXCOLOR(1.0f, 1.0f, 0.0f, 1.0f));
	g_pTxtHelper->DrawTextLine(DXUTGetFrameStats(true && DXUTIsVsyncEnabled()));
	g_pTxtHelper->DrawTextLine(DXUTGetDeviceStats());

	g_pTxtHelper->End();
}

void CALLBACK OnFrameMove(double fTime, float fElapsedTime, void* pUserContext)
{
	Camera::OnFrameMove(fTime, fElapsedTime, pUserContext);
}

void renderScene(ID3D11Device* pd3dDevice, ID3D11DeviceContext* pd3dImmediateContext);
void postProccessGBuffer(ID3D11Device* pd3dDevice, ID3D11DeviceContext* context);
void postProccessBlur(ID3D11Device* pd3dDevice, ID3D11DeviceContext* context, _In_opt_ std::function<void __cdecl()> setHState, _In_opt_ std::function<void __cdecl()> setVState);

void clearAndSetRenderTarget(ID3D11DeviceContext* context, float ClearColor[], int n, ID3D11RenderTargetView** pRTV, ID3D11DepthStencilView* pDSV){
	for (int i = 0; i < n; i++)
		context->ClearRenderTargetView(pRTV[i], ClearColor);

	context->ClearDepthStencilView(pDSV, D3D11_CLEAR_DEPTH, 1.0f, 0);

	context->OMSetRenderTargets(n, pRTV, pDSV); //renderTargetViewToArray(pRTV) DXUTGetD3D11RenderTargetView
}

void CALLBACK OnD3D11FrameRender(ID3D11Device* pd3dDevice, ID3D11DeviceContext* context,
	double fTime, float fElapsedTime, void* pUserContext)
{
	D3D11_VIEWPORT vp;
	vp.TopLeftX = 0;
	vp.TopLeftY = 0;
	vp.Width = scene_state.vFrustumParams.x;
	vp.Height = scene_state.vFrustumParams.y;
	vp.MinDepth = 0;
	vp.MaxDepth = 1;
	context->RSSetViewports(1, &vp);

	scene_state.time = XMFLOAT4(fTime, 0.0, 0.0, 0.0);

	set_scene_constant_buffer(context);

	float clearColor[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

	{
		clearAndSetRenderTarget(context, clearColor, 1, renderTargetViewToArray(DXUTGetD3D11RenderTargetView()), DXUTGetD3D11DepthStencilView());

		renderScene(pd3dDevice, context);
	}

	RenderText();
}

void skybox_set_world_matrix();
void skybox_draw(ID3D11DeviceContext* pd3dImmediateContext, IEffect* effect, _In_opt_ std::function<void __cdecl()> setCustomState);
void water_set_world_matrix();
void water_draw(ID3D11DeviceContext* pd3dImmediateContext, IEffect* effect, ID3D11InputLayout* inputLayout, _In_opt_ std::function<void __cdecl()> setCustomState);

void renderScene(ID3D11Device* pd3dDevice, ID3D11DeviceContext* context)
{
	/////
	context->VSSetConstantBuffers(0, 1, constantBuffersToArray(*(G->scene_constant_buffer)));
	
	context->PSSetSamplers(0, 1, samplerStateToArray(G->render_states->AnisotropicWrap()));

	context->VSSetSamplers(0, 1, samplerStateToArray(G->render_states->AnisotropicWrap()));
	/////

	skybox_set_world_matrix();

	set_scene_constant_buffer(context);

	skybox_draw(context, G->sky_box_effect.get(), [=]{
		context->GSSetConstantBuffers(0, 1, constantBuffersToArray(*(G->scene_constant_buffer)));

		context->PSSetShaderResources(1, 1, shaderResourceViewToArray(G->skybox_texture.Get()));

		context->OMSetBlendState(G->render_states->Opaque(), Colors::Black, 0xFFFFFFFF);
		context->RSSetState(G->render_states->CullClockwise());
		context->OMSetDepthStencilState(G->render_states->DepthNone(), 0);
	});

	water_set_world_matrix();

	set_scene_constant_buffer(context);

	water_draw(context, G->model_effect.get(), G->model_input_layout.Get(), [=]{
		context->PSSetConstantBuffers(0, 1, constantBuffersToArray(*(G->scene_constant_buffer)));

		context->PSSetShaderResources(1, 1, shaderResourceViewToArray(G->skybox_texture.Get()));

		context->PSSetShaderResources(2, 1, shaderResourceViewToArray(G->noise_3d_texture.Get()));

		context->VSSetShaderResources(2, 1, shaderResourceViewToArray(G->noise_3d_texture.Get()));

		context->OMSetBlendState(G->render_states->Opaque(), Colors::Black, 0xFFFFFFFF);
		context->RSSetState(G->render_states->CullNone());
		context->OMSetDepthStencilState(G->render_states->DepthDefault(), 0);
	});

	//wall_set_world_matrix();

	//set_scene_constant_buffer(context);

	//wall_draw(context, G->model_effect.get(), G->model_input_layout.Get(), [=]{
	//	context->PSSetShaderResources(0, 1, shaderResourceViewToArray(G->wall_texture.Get()));

	//	context->OMSetBlendState(G->render_states->Opaque(), Colors::Black, 0xFFFFFFFF);
	//	context->RSSetState(G->render_states->CullCounterClockwise());
	//	context->OMSetDepthStencilState(G->render_states->DepthDefault(), 0);
	//});
}