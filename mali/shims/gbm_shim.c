#include <gbm.h>
#include <stdint.h>

uint64_t gbm_bo_get_modifier(struct gbm_bo *bo)
{
    (void)bo;
    return 0; /* DRM_FORMAT_MOD_LINEAR */
}

int gbm_bo_get_plane_count(struct gbm_bo *bo)
{
    (void)bo;
    return 1;
}

union gbm_bo_handle gbm_bo_get_handle_for_plane(struct gbm_bo *bo, int plane)
{
    if (plane != 0) {
        union gbm_bo_handle invalid;
        invalid.s32 = -1;
        return invalid;
    }
    return gbm_bo_get_handle(bo);
}

uint32_t gbm_bo_get_stride_for_plane(struct gbm_bo *bo, int plane)
{
    if (plane != 0)
        return 0;
    return gbm_bo_get_stride(bo);
}

uint32_t gbm_bo_get_offset(struct gbm_bo *bo, int plane)
{
    (void)bo;
    (void)plane;
    return 0;
}
